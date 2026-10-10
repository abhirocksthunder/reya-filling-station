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
            children: [
              Text(
                '${shift.shiftName} • ${shift.businessDate}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: StationColors.textMedium,
                ),
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

          // Big Forecourt Primary Action: Scan Totaliser
          InkWell(
            onTap: () {
              if (!isInsideGeofence && state.settings.checkLocationBeforeScan) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot scan: Device is outside 150m station perimeter. Move closer to pump.'),
                    backgroundColor: StationColors.errorRed,
                  ),
                );
              } else {
                onTabChange(1); // Switch to Scan tab
              }
            },
            borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: StationColors.primary,
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
                          AppStrings.get('takePhotoPrintout', lang),
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
}
