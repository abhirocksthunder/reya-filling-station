import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/pump.dart';
import '../../services/station_state_provider.dart';
import 'package:image_picker/image_picker.dart';

class PumpSetupScreen extends StatefulWidget {
  const PumpSetupScreen({super.key});

  @override
  State<PumpSetupScreen> createState() => _PumpSetupScreenState();
}

class _PumpSetupScreenState extends State<PumpSetupScreen> {
  int _selectedPumpIdx = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final pumps = state.pumps;
    if (pumps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_gas_station_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No pumps configured yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Add your first forecourt petrol/diesel dispenser to begin.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppStrings.get('addPump', lang)),
                style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary, foregroundColor: Colors.white),
                onPressed: () => _showAddPumpDialog(context, state),
              ),
            ],
          ),
        ),
      );
    }

    final pump = pumps[_selectedPumpIdx.clamp(0, pumps.length - 1)];

    return LayoutBuilder(
      builder: (context, screenConstraints) {
        final isMobile = screenConstraints.maxWidth < 600;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Header
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    AppStrings.get('pumpsAndReceiptSetup', lang),
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 26,
                      fontWeight: FontWeight.w800,
                      color: StationColors.textDark,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppStrings.get('addPump', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(44, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showAddPumpDialog(context, state),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Horizontal Scrollable Pump Selector Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(pumps.length, (i) {
                    bool isSelected = i == _selectedPumpIdx;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(pumps[i].name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : StationColors.textDark)),
                        selected: isSelected,
                        selectedColor: StationColors.primary,
                        onSelected: (val) {
                          if (val) setState(() => _selectedPumpIdx = i);
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),

          // Two-column Setup Layout
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;

              Widget leftSetupCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(pump.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: StationColors.textDark)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: pump.active ? StationColors.successBg : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: pump.active ? StationColors.successGreen.withOpacity(0.4) : Colors.grey),
                                      ),
                                      child: Text(
                                        pump.active ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: pump.active ? StationColors.successGreen : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${AppStrings.get("serialNumber", lang)}: ${pump.serialNumber}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: StationColors.textMedium),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  label: Text(AppStrings.get('editPump', lang)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: StationColors.primary,
                                    side: const BorderSide(color: StationColors.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _showEditPumpDialog(context, state, pump),
                                ),
                                if (pumps.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    tooltip: AppStrings.get('deletePump', lang),
                                    onPressed: () => _confirmDeletePump(context, state, pump),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Nozzles Table (Horizontally scrollable on narrow mobile screens)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: StationColors.divider),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: (constraints.maxWidth - 42).clamp(380.0, 900.0),
                                ),
                                child: Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(1.1),
                                    1: FlexColumnWidth(1.0),
                                    2: FlexColumnWidth(1.3),
                                    3: FlexColumnWidth(1.4),
                                  },
                                  children: [
                                    const TableRow(
                                      decoration: BoxDecoration(color: Color(0xFFF7F9F9)),
                                      children: [
                                        Padding(padding: EdgeInsets.all(8), child: Text('Nozzle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                        Padding(padding: EdgeInsets.all(8), child: Text('Fuel type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                        Padding(padding: EdgeInsets.all(8), child: Text('Receipt mapping', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                        Padding(padding: EdgeInsets.all(8), child: Text('Previous reading', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      ],
                                    ),
                                    ...pump.nozzles.map((n) {
                                      return TableRow(
                                        children: [
                                          Padding(padding: const EdgeInsets.all(8), child: Text('Nozzle ${n.nozzleNumber}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                                          Padding(padding: const EdgeInsets.all(8), child: Text(n.fuelType, style: const TextStyle(fontSize: 13))),
                                          const Padding(padding: EdgeInsets.all(8), child: Text('Preview mapping', style: TextStyle(fontSize: 12, color: Colors.blueGrey))),
                                          Padding(padding: const EdgeInsets.all(8), child: Text(n.formattedPreviousReading, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.grey),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text('Confirm fuel mapping from station setup.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Fuel Rates Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
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
                            const Text('Fuel rates (owner configured)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            TextButton.icon(
                              icon: const Icon(Icons.edit_note, size: 16),
                              label: const Text('Edit rates'),
                              onPressed: () => _showEditPumpDialog(context, state, pump),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F9F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Petrol (₹/L)', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getFuelRateDisplay(pump, 'Petrol'),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: StationColors.textDark),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F9F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Diesel (₹/L)', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getFuelRateDisplay(pump, 'Diesel'),
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: StationColors.textDark),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Baseline Readings
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Initial baseline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text('Set approved opening reading if starting fresh or after meter change.', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.lock_reset, size: 18),
                          label: const Text('Set opening baseline'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showSetOpeningBaselineDialog(context, state, pump),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              Widget rightReferenceCol = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Base Totaliser Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: StationColors.successBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: StationColors.successGreen.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 14, color: StationColors.successGreen),
                              SizedBox(width: 4),
                              Text('Owner Verified Base', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: StationColors.successGreen)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Authoritative baseline totaliser image used to validate staff receipt uploads & prevent erroneous entries.',
                      style: TextStyle(fontSize: 12, color: StationColors.textLight),
                    ),
                    const SizedBox(height: 14),

                    // Printout preview with IndianOil branding & dynamic values
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF8F1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2D9C8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Column(
                              children: [
                                Icon(Icons.circle, color: Colors.orange, size: 28),
                                Text('IndianOil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('FP. ID          : ${pump.id.replaceAll('pump_', '')}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          Text('Pump SNo   : ${pump.serialNumber}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          Text('Date           : ${DateFormatter.formatDisplayDate(DateTime.now())}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          Text('Time           : ${DateFormatter.formatDisplayTime(DateTime.now())}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          const Divider(height: 12),
                          if (pump.nozzles.isNotEmpty) ...[
                            Text('Nozzle No1 (${pump.nozzles[0].fuelType})', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('CumVolume: ${pump.nozzles[0].formattedReading.replaceAll(' L', '')}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          ],
                          if (pump.nozzles.length > 1) ...[
                            const SizedBox(height: 6),
                            Text('Nozzle No2 (${pump.nozzles[1].fuelType})', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('CumVolume: ${pump.nozzles[1].formattedReading.replaceAll(' L', '')}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Receipt template & mapping', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text('IndianOil Automation v1', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    const Text('Field mapping (from receipt)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('• CumVolume  →  Cumulative volume (L)', style: TextStyle(fontSize: 12)),
                    const Text('• Date        →  Transaction date & time', style: TextStyle(fontSize: 12)),
                    const Text('• Pump serial →  Pump SNo', style: TextStyle(fontSize: 12)),
                    const Text('• Nozzle      →  Nozzle number', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_photo_alternate, size: 18, color: Colors.white),
                        label: const Text('Upload Base Totaliser Proof Image', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StationColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showUploadBaseProofDialog(context, state, pump),
                      ),
                    ),
                  ],
                ),
              );

              if (!isWide) {
                return Column(
                  children: [
                    leftSetupCol,
                    const SizedBox(height: 20),
                    rightReferenceCol,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: leftSetupCol),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: rightReferenceCol),
                ],
              );
            },
          ),
        ],
      ),
    );
      },
    );
  }

  void _showSetOpeningBaselineDialog(BuildContext context, StationStateProvider state, Pump pump) {
    final n1 = pump.nozzles.isNotEmpty ? pump.nozzles[0] : null;
    final n2 = pump.nozzles.length > 1 ? pump.nozzles[1] : null;

    final n1Ctrl = TextEditingController(
      text: n1 != null ? (n1.previousAcceptedReadingMl / 1000.0).toStringAsFixed(3) : '',
    );
    final n2Ctrl = TextEditingController(
      text: n2 != null ? (n2.previousAcceptedReadingMl / 1000.0).toStringAsFixed(3) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.lock_reset, color: StationColors.primary),
            const SizedBox(width: 10),
            Text('Set Opening Baseline: ${pump.name}'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set the approved opening cumulative readings for ${pump.name} (SNo: ${pump.serialNumber}). Future shift dispensing will be calculated starting from this baseline.',
                style: const TextStyle(fontSize: 13, color: StationColors.textMedium),
              ),
              const SizedBox(height: 16),
              if (n1 != null) ...[
                TextField(
                  controller: n1Ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  maxLength: 15,
                  inputFormatters: [LengthLimitingTextInputFormatter(15)],
                  decoration: InputDecoration(
                    labelText: 'Nozzle 1 (${n1.fuelType}) Opening Litres',
                    helperText: 'Current baseline: ${n1.formattedPreviousReading}',
                    counterText: '',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (n2 != null) ...[
                TextField(
                  controller: n2Ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  maxLength: 15,
                  inputFormatters: [LengthLimitingTextInputFormatter(15)],
                  decoration: InputDecoration(
                    labelText: 'Nozzle 2 (${n2.fuelType}) Opening Litres',
                    helperText: 'Current baseline: ${n2.formattedPreviousReading}',
                    counterText: '',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 16, color: Colors.white),
            label: const Text('Save Baseline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.successGreen),
            onPressed: () {
              final double? val1 = double.tryParse(n1Ctrl.text);
              final double? val2 = double.tryParse(n2Ctrl.text);
              if (val1 == null || val2 == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid numeric baseline readings.')),
                );
                return;
              }

              state.setPumpOpeningBaseline(pump.id, val1, val2);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening baseline updated successfully for ${pump.name}!'),
                  backgroundColor: StationColors.successGreen,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showUploadBaseProofDialog(BuildContext context, StationStateProvider state, Pump pump) {
    String? selectedImagePath;
    String displayLabel = pump.referenceReceiptAsset ?? 'assets/images/media_1791634198035.png';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: StationColors.primary),
              const SizedBox(width: 10),
              Text('Base Totaliser Proof: ${pump.name}'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload or take an authoritative totaliser photo for this dispenser. Shift staff uploads will be validated against this baseline.',
                  style: TextStyle(fontSize: 13, color: StationColors.textMedium),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF8F1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2D9C8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.image, size: 36, color: StationColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Baseline Proof: $displayLabel', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('IndianOil Pump SNo: ${pump.serialNumber}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      label: const Text('Take Camera Pic', style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final file = await picker.pickImage(
                          source: ImageSource.camera,
                          maxWidth: 1280,
                          maxHeight: 1280,
                          imageQuality: 75,
                        );
                        if (file != null) {
                          final bytes = await file.readAsBytes();
                          final b64 = base64Encode(bytes);
                          setDialogState(() {
                            selectedImagePath = 'data:image/jpeg;base64,$b64';
                            displayLabel = 'Captured: ${file.name}';
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 16),
                      label: const Text('Pick from Gallery', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final file = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1280,
                          maxHeight: 1280,
                          imageQuality: 75,
                        );
                        if (file != null) {
                          final bytes = await file.readAsBytes();
                          final b64 = base64Encode(bytes);
                          setDialogState(() {
                            selectedImagePath = 'data:image/jpeg;base64,$b64';
                            displayLabel = 'Selected: ${file.name}';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
              label: const Text('Save Proof Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: StationColors.successGreen),
              onPressed: () {
                final pathToSave = selectedImagePath ?? pump.referenceReceiptAsset ?? 'assets/images/media_1791634198035.png';
                state.updatePumpBaseTotaliserImage(pump.id, pathToSave);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Authoritative base totaliser proof updated for ${pump.name} (SNo: ${pump.serialNumber})!'),
                    backgroundColor: StationColors.successGreen,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getFuelRateDisplay(Pump pump, String fuelType) {
    for (final n in pump.nozzles) {
      if (n.fuelType.toLowerCase() == fuelType.toLowerCase()) {
        return (n.ratePaisePerLitre / 100.0).toStringAsFixed(2);
      }
    }
    return fuelType.toLowerCase() == 'petrol' ? '117.52' : '105.21';
  }

  void _showAddPumpDialog(BuildContext context, StationStateProvider state) {
    final lang = state.currentLanguage;
    final nameCtrl = TextEditingController(text: 'Pump ${state.pumps.length + 1}');
    final serialCtrl = TextEditingController();

    String n1Type = 'Petrol';
    final n1RateCtrl = TextEditingController(text: '117.52');
    final n1ReadingCtrl = TextEditingController(text: '0.000');

    String n2Type = 'Diesel';
    final n2RateCtrl = TextEditingController(text: '105.21');
    final n2ReadingCtrl = TextEditingController(text: '0.000');

    bool isActive = true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.local_gas_station_rounded, color: StationColors.primary),
              const SizedBox(width: 10),
              Text(AppStrings.get('addPump', lang)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configure a new petrol/diesel dispenser for the station forecourt.',
                      style: TextStyle(fontSize: 13, color: StationColors.textMedium),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      maxLength: 30,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: InputDecoration(
                        labelText: '${AppStrings.get("pumpName", lang)} *',
                        hintText: 'e.g. Pump 3',
                        counterText: '',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Pump name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: serialCtrl,
                      maxLength: 30,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: InputDecoration(
                        labelText: '${AppStrings.get("serialNumber", lang)} *',
                        hintText: 'e.g. 202501001295',
                        counterText: '',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        helperText: 'IndianOil serial printed on automation slips for OCR validation',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Serial number is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Nozzle 1 Configuration
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StationColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nozzle 1 Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: n1Type,
                                  decoration: const InputDecoration(
                                    labelText: 'Fuel Type',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Petrol', child: Text('Petrol')),
                                    DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        n1Type = val;
                                        if (val == 'Petrol' && n1RateCtrl.text == '105.21') {
                                          n1RateCtrl.text = '117.52';
                                        } else if (val == 'Diesel' && n1RateCtrl.text == '117.52') {
                                          n1RateCtrl.text = '105.21';
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: n1RateCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  maxLength: 10,
                                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                                  decoration: const InputDecoration(
                                    labelText: 'Rate (₹/L)',
                                    counterText: '',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid rate' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: n1ReadingCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            maxLength: 15,
                            inputFormatters: [LengthLimitingTextInputFormatter(15)],
                            decoration: const InputDecoration(
                              labelText: 'Initial Totaliser Reading (Litres)',
                              hintText: '0.000',
                              counterText: '',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid volume' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Nozzle 2 Configuration
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StationColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nozzle 2 Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: n2Type,
                                  decoration: const InputDecoration(
                                    labelText: 'Fuel Type',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Petrol', child: Text('Petrol')),
                                    DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() {
                                        n2Type = val;
                                        if (val == 'Petrol' && n2RateCtrl.text == '105.21') {
                                          n2RateCtrl.text = '117.52';
                                        } else if (val == 'Diesel' && n2RateCtrl.text == '117.52') {
                                          n2RateCtrl.text = '105.21';
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: n2RateCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  maxLength: 10,
                                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                                  decoration: const InputDecoration(
                                    labelText: 'Rate (₹/L)',
                                    counterText: '',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid rate' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: n2ReadingCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            maxLength: 15,
                            inputFormatters: [LengthLimitingTextInputFormatter(15)],
                            decoration: const InputDecoration(
                              labelText: 'Initial Totaliser Reading (Litres)',
                              hintText: '0.000',
                              counterText: '',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid volume' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('Active Dispenser', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Available for shift scans and forecourt dispensing', style: TextStyle(fontSize: 12)),
                      value: isActive,
                      activeColor: StationColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
              label: const Text('Create Pump', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                final n1Rate = ((double.tryParse(n1RateCtrl.text) ?? 117.52) * 100).round();
                final n1Vol = (((double.tryParse(n1ReadingCtrl.text) ?? 0.0)) * 1000).round();
                final n2Rate = ((double.tryParse(n2RateCtrl.text) ?? 105.21) * 100).round();
                final n2Vol = (((double.tryParse(n2ReadingCtrl.text) ?? 0.0)) * 1000).round();

                final pumpId = 'pump_${DateTime.now().millisecondsSinceEpoch}';
                final newPump = Pump(
                  id: pumpId,
                  name: nameCtrl.text.trim(),
                  serialNumber: serialCtrl.text.trim(),
                  active: isActive,
                  referenceReceiptAsset: 'assets/images/media_1791634198035.png',
                  nozzles: [
                    Nozzle(
                      id: '${pumpId}_n1',
                      pumpId: pumpId,
                      nozzleNumber: 1,
                      fuelType: n1Type,
                      ratePaisePerLitre: n1Rate,
                      currentTotaliserMl: n1Vol,
                      previousAcceptedReadingMl: n1Vol,
                      previousReadingTimestamp: DateTime.now(),
                      active: true,
                    ),
                    Nozzle(
                      id: '${pumpId}_n2',
                      pumpId: pumpId,
                      nozzleNumber: 2,
                      fuelType: n2Type,
                      ratePaisePerLitre: n2Rate,
                      currentTotaliserMl: n2Vol,
                      previousAcceptedReadingMl: n2Vol,
                      previousReadingTimestamp: DateTime.now(),
                      active: true,
                    ),
                  ],
                );

                state.addPump(newPump);
                setState(() {
                  _selectedPumpIdx = state.pumps.length - 1;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pump "${newPump.name}" added successfully!'),
                    backgroundColor: StationColors.successGreen,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPumpDialog(BuildContext context, StationStateProvider state, Pump pump) {
    final lang = state.currentLanguage;
    final nameCtrl = TextEditingController(text: pump.name);
    final serialCtrl = TextEditingController(text: pump.serialNumber);

    final n1 = pump.nozzles.isNotEmpty ? pump.nozzles[0] : null;
    final n2 = pump.nozzles.length > 1 ? pump.nozzles[1] : null;

    String n1Type = n1?.fuelType ?? 'Petrol';
    final n1RateCtrl = TextEditingController(
      text: n1 != null ? (n1.ratePaisePerLitre / 100.0).toStringAsFixed(2) : '117.52',
    );
    final n1CurrentReadingCtrl = TextEditingController(
      text: n1 != null ? (n1.currentTotaliserMl / 1000.0).toStringAsFixed(3) : '0.000',
    );
    final n1BaselineCtrl = TextEditingController(
      text: n1 != null ? (n1.previousAcceptedReadingMl / 1000.0).toStringAsFixed(3) : '0.000',
    );

    String n2Type = n2?.fuelType ?? 'Diesel';
    final n2RateCtrl = TextEditingController(
      text: n2 != null ? (n2.ratePaisePerLitre / 100.0).toStringAsFixed(2) : '105.21',
    );
    final n2CurrentReadingCtrl = TextEditingController(
      text: n2 != null ? (n2.currentTotaliserMl / 1000.0).toStringAsFixed(3) : '0.000',
    );
    final n2BaselineCtrl = TextEditingController(
      text: n2 != null ? (n2.previousAcceptedReadingMl / 1000.0).toStringAsFixed(3) : '0.000',
    );

    bool isActive = pump.active;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: StationColors.primary),
              const SizedBox(width: 10),
              Text('${AppStrings.get("editPump", lang)}: ${pump.name}'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update dispenser details, IndianOil serial number, fuel rates, or totaliser baseline.',
                      style: TextStyle(fontSize: 13, color: StationColors.textMedium),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      maxLength: 30,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: InputDecoration(
                        labelText: '${AppStrings.get("pumpName", lang)} *',
                        counterText: '',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Pump name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: serialCtrl,
                      maxLength: 30,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: InputDecoration(
                        labelText: '${AppStrings.get("serialNumber", lang)} *',
                        counterText: '',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        helperText: 'Must match printed slip serial number for OCR validation',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Serial number is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Nozzle 1 Configuration
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StationColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nozzle 1 Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: n1Type,
                                  decoration: const InputDecoration(
                                    labelText: 'Fuel Type',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Petrol', child: Text('Petrol')),
                                    DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => n1Type = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: n1RateCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  maxLength: 10,
                                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                                  decoration: const InputDecoration(
                                    labelText: 'Rate (₹/L)',
                                    counterText: '',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid rate' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: n1CurrentReadingCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  maxLength: 15,
                                  inputFormatters: [LengthLimitingTextInputFormatter(15)],
                                  decoration: const InputDecoration(
                                    labelText: 'Current Totaliser (L)',
                                    counterText: '',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: n1BaselineCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  maxLength: 15,
                                  inputFormatters: [LengthLimitingTextInputFormatter(15)],
                                  decoration: const InputDecoration(
                                    labelText: 'Opening Baseline (L)',
                                    counterText: '',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Nozzle 2 Configuration
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StationColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nozzle 2 Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: n2Type,
                                  decoration: const InputDecoration(
                                    labelText: 'Fuel Type',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Petrol', child: Text('Petrol')),
                                    DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => n2Type = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: n2RateCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  maxLength: 10,
                                  inputFormatters: [LengthLimitingTextInputFormatter(10)],
                                  decoration: const InputDecoration(
                                    labelText: 'Rate (₹/L)',
                                    counterText: '',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid rate' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: n2CurrentReadingCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  maxLength: 15,
                                  inputFormatters: [LengthLimitingTextInputFormatter(15)],
                                  decoration: const InputDecoration(
                                    labelText: 'Current Totaliser (L)',
                                    counterText: '',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: n2BaselineCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  maxLength: 15,
                                  inputFormatters: [LengthLimitingTextInputFormatter(15)],
                                  decoration: const InputDecoration(
                                    labelText: 'Opening Baseline (L)',
                                    counterText: '',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('Active Dispenser', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Available for shift scans and forecourt dispensing', style: TextStyle(fontSize: 12)),
                      value: isActive,
                      activeColor: StationColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined, size: 16, color: Colors.white),
              label: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                final n1Rate = ((double.tryParse(n1RateCtrl.text) ?? 117.52) * 100).round();
                final n1Cur = (((double.tryParse(n1CurrentReadingCtrl.text) ?? 0.0)) * 1000).round();
                final n1Base = (((double.tryParse(n1BaselineCtrl.text) ?? 0.0)) * 1000).round();

                final n2Rate = ((double.tryParse(n2RateCtrl.text) ?? 105.21) * 100).round();
                final n2Cur = (((double.tryParse(n2CurrentReadingCtrl.text) ?? 0.0)) * 1000).round();
                final n2Base = (((double.tryParse(n2BaselineCtrl.text) ?? 0.0)) * 1000).round();

                List<Nozzle> updatedNozzles = [];
                if (pump.nozzles.isNotEmpty) {
                  updatedNozzles.add(pump.nozzles[0].copyWith(
                    fuelType: n1Type,
                    ratePaisePerLitre: n1Rate,
                    currentTotaliserMl: n1Cur,
                    previousAcceptedReadingMl: n1Base,
                  ));
                } else {
                  updatedNozzles.add(Nozzle(
                    id: '${pump.id}_n1',
                    pumpId: pump.id,
                    nozzleNumber: 1,
                    fuelType: n1Type,
                    ratePaisePerLitre: n1Rate,
                    currentTotaliserMl: n1Cur,
                    previousAcceptedReadingMl: n1Base,
                  ));
                }

                if (pump.nozzles.length > 1) {
                  updatedNozzles.add(pump.nozzles[1].copyWith(
                    fuelType: n2Type,
                    ratePaisePerLitre: n2Rate,
                    currentTotaliserMl: n2Cur,
                    previousAcceptedReadingMl: n2Base,
                  ));
                } else {
                  updatedNozzles.add(Nozzle(
                    id: '${pump.id}_n2',
                    pumpId: pump.id,
                    nozzleNumber: 2,
                    fuelType: n2Type,
                    ratePaisePerLitre: n2Rate,
                    currentTotaliserMl: n2Cur,
                    previousAcceptedReadingMl: n2Base,
                  ));
                }

                final updated = pump.copyWith(
                  name: nameCtrl.text.trim(),
                  serialNumber: serialCtrl.text.trim(),
                  active: isActive,
                  nozzles: updatedNozzles,
                );

                state.updatePump(updated);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pump "${updated.name}" updated successfully!'),
                    backgroundColor: StationColors.successGreen,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePump(BuildContext context, StationStateProvider state, Pump pump) {
    final lang = state.currentLanguage;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(AppStrings.get('deletePump', lang)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${pump.name} (SNo: ${pump.serialNumber})? This will remove this dispenser from shift scans and owner review.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              state.deletePump(pump.id);
              setState(() {
                _selectedPumpIdx = 0;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${pump.name} deleted successfully.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('Delete Pump', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
