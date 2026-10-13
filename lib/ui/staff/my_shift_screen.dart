import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/currency_formatter.dart';
import '../../core/formatting/date_formatter.dart';
import '../../core/formatting/volume_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/user_profile.dart';
import '../../services/location_service.dart';
import '../../services/station_state_provider.dart';
import '../../widgets/version_footer.dart';

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
    final isShiftInProgress = state.isUserShiftInProgress(user);
    final isTrackingEnabled = state.settings.enableLiveLocationTracking;
    final userLat = user.lastLatitude ?? state.settings.latitude;
    final userLon = user.lastLongitude ?? state.settings.longitude;
    final locationName = state.resolveUserLocationName(user);

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${shift.shiftName} • ${shift.businessDate}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: StationColors.textMedium,
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (!isShiftInProgress) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
                      label: const Text('Start shift', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StationColors.successGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(60, 44),
                      ),
                      onPressed: () {
                        state.startCurrentUserShift();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Shift started. Live location tracking is active until shift close.'),
                            backgroundColor: StationColors.successGreen,
                          ),
                        );
                      },
                    ),
                  ],
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule, size: 14),
                    label: const Text('Change shift', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(60, 44),
                      side: const BorderSide(color: StationColors.primary),
                      foregroundColor: StationColors.primary,
                    ),
                    onPressed: () => _showShiftTimingRequestDialog(context, state, user),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Geofence & Clickable Google Maps Location Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => LocationService.openInGoogleMaps(
                    lat: userLat,
                    lon: userLon,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isInsideGeofence
                          ? StationColors.successGreen.withOpacity(0.08)
                          : StationColors.errorRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isInsideGeofence
                            ? StationColors.successGreen.withOpacity(0.35)
                            : StationColors.errorRed.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 15,
                          color: isInsideGeofence ? StationColors.successGreen : StationColors.errorRed,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            !isTrackingEnabled
                                ? '$locationName • Location tracking off'
                                : !isShiftInProgress
                                    ? '$locationName • Shift closed (tracking paused)'
                                    : '${isInsideGeofence ? AppStrings.get('atStation', lang) : AppStrings.get('outsideStation', lang)} • $locationName (${userLat.toStringAsFixed(4)}°N, ${userLon.toStringAsFixed(4)}°E)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isInsideGeofence ? StationColors.successGreen : StationColors.errorRed,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 13,
                          color: isInsideGeofence ? StationColors.successGreen : StationColors.errorRed,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const VersionFooter(compact: true),
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
                state.setActiveScanPumpId(state.pumps.isNotEmpty ? state.pumps.first.id : 'pump_1');
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
          if (state.canAccessScreen('people_management')) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: () => onTabChange(4), // Switch to Users tab in StaffShell
              borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.primary.withOpacity(0.35), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: StationColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.group_add_rounded, color: StationColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add / Update Users & Share APK',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: StationColors.textDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Submit new/updated staff for Owner approval & share app link',
                            style: TextStyle(
                              fontSize: 12,
                              color: StationColors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: StationColors.primary),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Last Recorded Readings Card
          Builder(
            builder: (context) {
              DateTime? latestScanTime;
              if (state.receipts.isNotEmpty) {
                latestScanTime = state.receipts.first.capturedAt;
              } else {
                for (var pump in state.pumps) {
                  for (var nozzle in pump.nozzles) {
                    if (nozzle.previousReadingTimestamp != null) {
                      if (latestScanTime == null || nozzle.previousReadingTimestamp!.isAfter(latestScanTime)) {
                        latestScanTime = nozzle.previousReadingTimestamp;
                      }
                    }
                  }
                }
              }

              final String recordedText = latestScanTime != null
                  ? '${AppStrings.get('lastRecorded', lang)} • ${DateFormatter.formatDisplayDate(latestScanTime)} ${DateFormatter.formatDisplayTime(latestScanTime)}'
                  : '${AppStrings.get('lastRecorded', lang)} • Awaiting today\'s scan';

              return Text(
                recordedText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: StationColors.textDark,
                ),
              );
            },
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

          // Pump 1 & Pump 2 Nozzle Readings (Dynamic from state.pumps)
          Column(
            children: state.pumps.map((pump) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pump Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF7F9F9),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        border: Border(bottom: BorderSide(color: StationColors.divider)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.local_gas_station_outlined, color: StationColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${pump.name} (SNo: ${pump.serialNumber})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: StationColors.textDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.camera_alt, size: 14),
                            label: const Text('Scan Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              state.setActiveScanPumpId(pump.id);
                              onTabChange(1);
                            },
                          ),
                        ],
                      ),
                    ),
                    // Nozzle rows
                    ...pump.nozzles.map((n) {
                      final hasTodayReading = n.currentTotaliserMl > n.previousAcceptedReadingMl;
                      final dispensedMl = n.currentTotaliserMl - n.previousAcceptedReadingMl;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              state.setActiveScanPumpId(pump.id);
                              onTabChange(1);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          runSpacing: 2,
                                          children: [
                                            Text(
                                              n.displayName,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: StationColors.textDark),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: n.fuelType == 'Petrol'
                                                    ? StationColors.primaryLight.withOpacity(0.15)
                                                    : StationColors.accentOrangeLight,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                n.fuelType,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: n.fuelType == 'Petrol' ? StationColors.primary : StationColors.accentOrange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Prev: ${n.formattedPreviousReading}',
                                          style: const TextStyle(fontSize: 11, color: StationColors.textLight),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        n.formattedReading,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StationColors.textDark),
                                      ),
                                      const SizedBox(height: 2),
                                      if (hasTodayReading) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: StationColors.successBg,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '+${VolumeFormatter.formatMl(dispensedMl)} today ✓',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: StationColors.successGreen),
                                          ),
                                        ),
                                      ] else ...[
                                        const Text(
                                          'Awaiting today\'s scan',
                                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.chevron_right, color: StationColors.textLight, size: 20),
                                ],
                              ),
                            ),
                          ),
                          if (n != pump.nozzles.last)
                            const Divider(height: 1, color: StationColors.divider),
                        ],
                      );
                    }),
                  ],
                ),
              );
            }).toList(),
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
                  CurrencyFormatter.formatPaise(
                    state.getShiftHandoverToOwnerPaise(shift, date: DateTime.now()),
                  ),
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
