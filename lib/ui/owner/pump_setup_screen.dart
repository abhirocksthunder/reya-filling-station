import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
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
                    const Text('Reference receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    // Printout preview with IndianOil branding
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF8F1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2D9C8)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.circle, color: Colors.orange, size: 28),
                                Text('IndianOil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          Text('FP. ID          : 1', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          Text('Pump SNo   : 202501001272', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          Text('Date           : 09/10/2026', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          Text('Time           : 21:50:29', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          Divider(height: 12),
                          Text('Nozzle No1', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('CumVolume: 169923.720', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          SizedBox(height: 6),
                          Text('Nozzle No2', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('CumVolume: 274487.190', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Receipt template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text('Template v1', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Upload reference receipt'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {},
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
}
