import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/pump.dart';
import '../../services/station_state_provider.dart';

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
    final pump = pumps[_selectedPumpIdx.clamp(0, pumps.length - 1)];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('pumpsAndReceiptSetup', lang),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('+ Add pump', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StationColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pump Selector Tabs
          Row(
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
                        Text(pump.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: StationColors.textDark)),
                        const SizedBox(height: 4),
                        Text('Serial number: ${pump.serialNumber}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: StationColors.textMedium)),
                        const SizedBox(height: 16),
                        // Nozzles Table
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: StationColors.divider),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Table(
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
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.grey),
                            SizedBox(width: 6),
                            Text('Confirm fuel mapping from station setup.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                        const Text('Fuel rates (owner configured)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Petrol (₹/L)', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                                    SizedBox(height: 4),
                                    Text('117.52', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: StationColors.textDark)),
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
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Diesel (₹/L)', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                                    SizedBox(height: 4),
                                    Text('105.21', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: StationColors.textDark)),
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
                          onPressed: () {},
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
  }

  void _showUploadBaseProofDialog(BuildContext context, StationStateProvider state, Pump pump) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: StationColors.primary),
            const SizedBox(width: 10),
            Text('Base Totaliser Proof: ${pump.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload or select an authoritative totaliser photo. Shift staff uploads will be validated against this baseline to eliminate fraudulent or incorrect updates.',
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
                        Text('Current baseline: ${pump.referenceReceiptAsset ?? "assets/images/media_1791616403909.jpg"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const Text('IndianOil Pump SNo: 202501001272', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              state.updatePumpBaseTotaliserImage(pump.id, 'assets/images/media_1791616403909.jpg');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Authoritative base totaliser proof updated for ${pump.name}!'),
                  backgroundColor: StationColors.successGreen,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
