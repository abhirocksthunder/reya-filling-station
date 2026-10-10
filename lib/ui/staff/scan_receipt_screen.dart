import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../l10n/app_strings.dart';
import '../../models/receipt_scan.dart';
import '../../services/station_state_provider.dart';

class ScanReceiptScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const ScanReceiptScreen({super.key, this.onNavigate});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  int _selectedSampleIndex = 0; // 0 = 9 Oct Historical, 1 = 10 Oct Fresh Today

  final List<Map<String, dynamic>> _samples = [
    {
      'date': '09/10/2026',
      'displayDate': '9 Oct 2026',
      'time': '21:50:29',
      'pumpSNo': '202501001272',
      'fpId': '1',
      'nozzle1': 169923720,
      'nozzle2': 274487190,
      'isPreviousDay': true,
      'warning': 'This receipt is from 9 Oct 2026. Take today\'s printout.',
    },
    {
      'date': '10/10/2026',
      'displayDate': '10 Oct 2026',
      'time': '06:45:10',
      'pumpSNo': '202501001272',
      'fpId': '1',
      'nozzle1': 170218850,
      'nozzle2': 275095980,
      'isPreviousDay': false,
      'warning': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final sample = _samples[_selectedSampleIndex];

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

          // OCR Sample Simulation Toggle (for interactive review)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Simulation fixture:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.textMedium),
                ),
                DropdownButton<int>(
                  value: _selectedSampleIndex,
                  isDense: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('9 Oct (Previous-day slip)')),
                    DropdownMenuItem(value: 1, child: Text('10 Oct (Today fresh slip)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSampleIndex = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Printed Receipt View Card
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
                _buildReceiptLine('FP. ID', ': ${sample['fpId']}'),
                _buildReceiptLine('Pump SNo', ': ${sample['pumpSNo']}'),
                _buildReceiptLine('Date', ': ${sample['date']}'),
                _buildReceiptLine('Time', ': ${sample['time']}'),
                const Divider(height: 16, color: Color(0xFFD6CBBB)),
                const Text('Nozzle No1', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                Text('CumVolume: ${(sample['nozzle1'] / 1000.0).toStringAsFixed(3)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
                const SizedBox(height: 8),
                const Text('Nozzle No2', style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                Text('CumVolume: ${(sample['nozzle2'] / 1000.0).toStringAsFixed(3)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
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
                _buildSummaryRow(AppStrings.get('pump', lang), sample['fpId'].toString()),
                const SizedBox(height: 8),
                _buildSummaryRow(AppStrings.get('receiptDate', lang), sample['displayDate'].toString()),
                const SizedBox(height: 8),
                _buildSummaryRow('Nozzle 1', '${(sample['nozzle1'] / 1000.0).toStringAsFixed(3)} L', isBoldValue: true),
                const SizedBox(height: 8),
                _buildSummaryRow('Nozzle 2', '${(sample['nozzle2'] / 1000.0).toStringAsFixed(3)} L', isBoldValue: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Previous-day / Validation Alert Badge
          if (sample['isPreviousDay'])
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: StationColors.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: StationColors.warningBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: StationColors.warningAmber, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.get('previousDayReceipt', lang),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: StationColors.warningAmber,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.get('previousDayNotice', lang),
                          style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
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
                      'Valid today reading • Monotonic counter verified',
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

          // Bottom Action Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: StationDimensions.primaryButtonHeight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined, color: StationColors.primary),
                    label: Text(
                      AppStrings.get('retakePhoto', lang),
                      style: const TextStyle(
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
                        _selectedSampleIndex = (_selectedSampleIndex + 1) % _samples.length;
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
                      backgroundColor: sample['isPreviousDay'] ? Colors.blueGrey : StationColors.successGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(StationDimensions.buttonRadius),
                      ),
                    ),
                    onPressed: () {
                      final scan = ReceiptScan(
                        id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
                        pumpSerialNumber: sample['pumpSNo'],
                        fpId: sample['fpId'],
                        printedDate: sample['date'],
                        printedTime: sample['time'],
                        nozzleCumVolumeMl: {
                          1: sample['nozzle1'],
                          2: sample['nozzle2'],
                        },
                        imagePath: 'assets/images/media_1791616403909.jpg',
                        validationStatus: sample['isPreviousDay']
                            ? ReceiptValidationStatus.previousDayReceipt
                            : ReceiptValidationStatus.valid,
                        statusMessage: sample['isPreviousDay']
                            ? 'Flagged: historical 9 Oct printout.'
                            : 'Verified reading committed.',
                        capturedBy: '${state.currentUser.name} (live capture)',
                        capturedAt: DateTime.now(),
                      );
                      state.saveReceiptScan(scan);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(sample['isPreviousDay']
                              ? 'Saved reading with Previous-Day flag for Owner audit.'
                              : 'Totaliser reading saved successfully!'),
                          backgroundColor: sample['isPreviousDay'] ? Colors.amber[800] : StationColors.successGreen,
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
