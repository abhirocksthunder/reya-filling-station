import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/formatting/volume_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../services/station_state_provider.dart';

class MyShiftScreen extends StatelessWidget {
  final Function(int) onTabChange;

  const MyShiftScreen({super.key, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;
    final shift = state.activeShift;
    final user = state.currentUser;
    final isInsideGeofence = state.simulateInsideGeofence;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Shift Header
          Text(
            '${AppStrings.get('hello', lang)} ${user.name}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: StationColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${shift.shiftName} • ${shift.businessDate}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: StationColors.textMedium,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule, size: 14),
                label: const Text('Change shift', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(60, 32),
                  side: const BorderSide(color: StationColors.primary),
                  foregroundColor: StationColors.primary,
                ),
                onPressed: () => _showShiftTimingRequestDialog(context, state, user),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Geofence Station Badge
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isInsideGeofence ? StationColors.successGreen : StationColors.errorRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isInsideGeofence
                    ? AppStrings.get('atStation', lang)
                    : AppStrings.get('outsideStation', lang),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isInsideGeofence ? StationColors.successGreen : StationColors.errorRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Totaliser Camera Scanning Setting Warning if restricted by Owner
          if (!state.settings.allowStaffTotaliserCameraScan) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: StationColors.warningBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: StationColors.warningBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock, color: StationColors.warningAmber, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Totaliser camera scanning has been restricted by Station Owner in settings. Report totaliser readings directly to your manager.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: StationColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Big Forecourt Primary Action: Scan Totaliser
          InkWell(
            onTap: () {
              if (!state.settings.allowStaffTotaliserCameraScan) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Totaliser camera scan is restricted by Station Owner in station settings.'),
                    backgroundColor: StationColors.errorRed,
                  ),
                );
                return;
              }
              if (!isInsideGeofence && state.settings.checkLocationBeforeScan) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot scan: Device is outside station perimeter. Move closer to pump.'),
                    backgroundColor: StationColors.errorRed,
                  ),
                );
              } else {
                onTabChange(1); // Switch to Scan tab
              }
            },
            borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
            child: Opacity(
              opacity: state.settings.allowStaffTotaliserCameraScan ? 1.0 : 0.65,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: state.settings.allowStaffTotaliserCameraScan ? StationColors.primary : Colors.blueGrey[700],
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: StationColors.primaryDark.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('scanTotaliser', lang),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.settings.allowStaffTotaliserCameraScan
                                ? AppStrings.get('takePhotoPrintout', lang)
                                : 'Scan disabled by owner • Submit to manager',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Last Recorded Readings Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppStrings.get('lastRecorded', lang)} • 9 Oct',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: StationColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            AppStrings.get('previousReadingsNote', lang),
            style: const TextStyle(
              fontSize: 12,
              color: StationColors.textLight,
            ),
          ),
          const SizedBox(height: 12),

          // Nozzle 1 & Nozzle 2 Reading Tiles
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Column(
              children: [
                _buildReadingRow(
                  label: 'Nozzle 1',
                  reading: '169,923.720 L',
                  sub: 'Petrol • Rate ₹117.52',
                  onTap: () => onTabChange(1),
                ),
                const Divider(height: 1, color: StationColors.divider),
                _buildReadingRow(
                  label: 'Nozzle 2',
                  reading: '274,487.190 L',
                  sub: 'Diesel • Rate ₹105.21',
                  onTap: () => onTabChange(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cash Handover from Sample Sheet Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              border: Border.all(color: StationColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('cashHandover', lang),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: StationColors.textMedium,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.formatPaise(shift.cashHandoverPaise),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: StationColors.accentOrange,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: StationDimensions.secondaryButtonHeight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_circle_outline, color: StationColors.primary),
                    label: Text(
                      AppStrings.get('addEntry', lang),
                      style: const TextStyle(
                        color: StationColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: StationColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(StationDimensions.buttonRadius),
                      ),
                    ),
                    onPressed: () => onTabChange(2), // Switch to Entries tab
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReadingRow({
    required String label,
    required String reading,
    required String sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: StationColors.textDark,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12,
                      color: StationColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              reading,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: StationColors.textDark,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: StationColors.textLight, size: 20),
          ],
        ),
      ),
    );
  }

  void _showShiftTimingRequestDialog(BuildContext context, StationStateProvider state, dynamic user) {
    String selectedShift = 'Evening';
    final reasonCtrl = TextEditingController();
    final shiftTimings = state.settings.shiftTimings;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final timingRange = shiftTimings[selectedShift] ?? 'Configured hours';

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.schedule, color: StationColors.primary),
                SizedBox(width: 8),
                Text('Request Shift Timing Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Text(
                      'Currently Assigned: ${user.assignedShift ?? 'Morning'}\nRequires Manager or Owner approval.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.textDark),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Desired Shift:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: StationColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedShift,
                        isExpanded: true,
                        items: shiftTimings.keys.map((s) => DropdownMenuItem(value: s, child: Text('$s (${shiftTimings[s]})'))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedShift = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Reason for timing change:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Family function / doctor appointment',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
                onPressed: () async {
                  await state.requestShiftTimingChange(
                    staffId: user.id,
                    staffName: user.name,
                    requestedShift: selectedShift,
                    timingRange: timingRange,
                    reason: reasonCtrl.text.trim(),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Shift timing change request to $selectedShift ($timingRange) submitted for manager approval.'),
                      backgroundColor: StationColors.successGreen,
                    ),
                  );
                },
                child: const Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
