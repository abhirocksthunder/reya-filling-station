import 'package:flutter/material.dart';
import '../../widgets/ota_diagnostics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/formatting/date_formatter.dart';
import '../../l10n/app_strings.dart';
import '../../models/station_settings.dart';
import '../../models/apk_release.dart';
import '../../services/station_state_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/app_version_service.dart';
import '../../core/utils/url_launcher_helper.dart';
import '../../widgets/force_update_dialog.dart';

class StationSettingsScreen extends StatefulWidget {
  const StationSettingsScreen({super.key});

  @override
  State<StationSettingsScreen> createState() => _StationSettingsScreenState();
}

class _StationSettingsScreenState extends State<StationSettingsScreen> {
  int _selectedSettingsTab = 0; // 0 = Location & Scan, 1 = Entry categories, 2 = Shift Timings, 3 = Database & Testing, 4 = App Version

  late double _radius;
  late bool _checkLocation;
  late bool _enableLiveLocationTracking;
  late bool _allowStaffTotaliserScan;
  late String _ocrDebugAccess;
  late String _defaultLang;
  bool _isProcessingAction = false;

  late TextEditingController _stationNameController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  late TextEditingController _targetVersionController;
  late TextEditingController _targetBuildNumberController;
  late TextEditingController _updateUrlController;
  late TextEditingController _releaseNotesController;
  late bool _forceUpdate;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<StationStateProvider>(context, listen: false).settings;
    _radius = settings.radiusMeters;
    _checkLocation = settings.checkLocationBeforeScan;
    _enableLiveLocationTracking = settings.enableLiveLocationTracking;
    _allowStaffTotaliserScan = settings.allowStaffTotaliserCameraScan;
    _ocrDebugAccess = settings.ocrDebugIconAccess;
    _defaultLang = settings.defaultLanguage;

    _stationNameController = TextEditingController(text: settings.stationName);
    _latitudeController = TextEditingController(text: settings.latitude.toStringAsFixed(4));
    _longitudeController = TextEditingController(text: settings.longitude.toStringAsFixed(4));

    _targetVersionController = TextEditingController(text: settings.latestVersion);
    _targetBuildNumberController = TextEditingController(text: settings.latestBuildNumber.toString());
    _updateUrlController = TextEditingController(text: settings.updateUrl);
    _releaseNotesController = TextEditingController(text: settings.releaseNotes);
    _forceUpdate = settings.forceUpdate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<StationStateProvider>(context, listen: false)
            .purgeApkReleasesOlderThan(const Duration(days: 7));
      }
    });
  }

  @override
  void dispose() {
    _stationNameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _targetVersionController.dispose();
    _targetBuildNumberController.dispose();
    _updateUrlController.dispose();
    _releaseNotesController.dispose();
    super.dispose();
  }

  void _saveGeneralSettings(StationStateProvider state) {
    final double? parsedLat = double.tryParse(_latitudeController.text.trim());
    final double? parsedLon = double.tryParse(_longitudeController.text.trim());
    final String parsedName = _stationNameController.text.trim();

    if (parsedLat == null || parsedLon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid numeric latitude and longitude coordinates.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final updated = state.settings.copyWith(
      stationName: parsedName.isNotEmpty ? parsedName : state.settings.stationName,
      latitude: parsedLat,
      longitude: parsedLon,
      radiusMeters: _radius,
      checkLocationBeforeScan: _checkLocation,
      enableLiveLocationTracking: _enableLiveLocationTracking,
      allowStaffTotaliserCameraScan: _allowStaffTotaliserScan,
      ocrDebugIconAccess: _ocrDebugAccess,
      defaultLanguage: _defaultLang,
    );
    state.updateSettings(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Station location and settings saved: ${updated.stationName} (${parsedLat.toStringAsFixed(4)}° N, ${parsedLon.toStringAsFixed(4)}° E)'),
        backgroundColor: StationColors.successGreen,
      ),
    );
  }

  void _showEditLocationDialog(BuildContext context, StationStateProvider state) {
    final nameCtrl = TextEditingController(text: _stationNameController.text);
    final latCtrl = TextEditingController(text: _latitudeController.text);
    final lonCtrl = TextEditingController(text: _longitudeController.text);
    double tempRadius = _radius;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_location_alt_rounded, color: StationColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text('Edit Station Location & Perimeter', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update forecourt GPS coordinates and scanning perimeter radius. Staff scans are restricted within this boundary.',
                      style: TextStyle(fontSize: 13, color: StationColors.textMedium),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      maxLength: 30,
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      decoration: const InputDecoration(
                        labelText: 'Station Name / Location Address *',
                        hintText: 'e.g. Chatrai, Andhra Pradesh',
                        prefixIcon: Icon(Icons.location_on, color: StationColors.primary),
                        border: OutlineInputBorder(),
                        counterText: '',
                        isDense: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Location name is required' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            maxLength: 15,
                            inputFormatters: [LengthLimitingTextInputFormatter(15)],
                            decoration: const InputDecoration(
                              labelText: 'Latitude (°N) *',
                              hintText: '16.5062',
                              prefixIcon: Icon(Icons.my_location_rounded, size: 18),
                              border: OutlineInputBorder(),
                              counterText: '',
                              isDense: true,
                            ),
                            validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid latitude' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: lonCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            maxLength: 15,
                            inputFormatters: [LengthLimitingTextInputFormatter(15)],
                            decoration: const InputDecoration(
                              labelText: 'Longitude (°E) *',
                              hintText: '80.6480',
                              prefixIcon: Icon(Icons.explore_rounded, size: 18),
                              border: OutlineInputBorder(),
                              counterText: '',
                              isDense: true,
                            ),
                            validator: (v) => double.tryParse(v ?? '') == null ? 'Invalid longitude' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.local_gas_station, size: 14, color: StationColors.primary),
                          label: const Text('Chatrai Forecourt (16.5062, 80.6480)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameCtrl.text = 'Chatrai, Andhra Pradesh';
                              latCtrl.text = '16.5062';
                              lonCtrl.text = '80.6480';
                            });
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.alt_route, size: 14, color: StationColors.primary),
                          label: const Text('Chatrai Bypass (16.5085, 80.6495)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              nameCtrl.text = 'Chatrai Bypass Road';
                              latCtrl.text = '16.5085';
                              lonCtrl.text = '80.6495';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Perimeter radius: ${tempRadius.toInt()} m',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Slider(
                      value: tempRadius,
                      min: 100,
                      max: 200,
                      divisions: 10,
                      label: '${tempRadius.toInt()} m',
                      activeColor: StationColors.primary,
                      onChanged: (val) => setDialogState(() => tempRadius = val),
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
              icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: const Text('Save Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final double newLat = double.parse(latCtrl.text.trim());
                final double newLon = double.parse(lonCtrl.text.trim());
                final String newName = nameCtrl.text.trim();

                setState(() {
                  _stationNameController.text = newName;
                  _latitudeController.text = newLat.toStringAsFixed(4);
                  _longitudeController.text = newLon.toStringAsFixed(4);
                  _radius = tempRadius;
                });

                final updated = state.settings.copyWith(
                  stationName: newName,
                  latitude: newLat,
                  longitude: newLon,
                  radiusMeters: tempRadius,
                  checkLocationBeforeScan: _checkLocation,
                  allowStaffTotaliserCameraScan: _allowStaffTotaliserScan,
                  defaultLanguage: _defaultLang,
                );
                state.updateSettings(updated);

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Station location updated: $newName (${newLat.toStringAsFixed(4)}° N, ${newLon.toStringAsFixed(4)}° E)'),
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StationStateProvider>();
    final lang = state.currentLanguage;

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
                    AppStrings.get('stationSettings', lang),
                    style: TextStyle(
                      fontSize: isMobile ? 22 : 26,
                      fontWeight: FontWeight.w800,
                      color: StationColors.textDark,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                    label: const Text('Save settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.primary,
                      minimumSize: const Size(130, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _saveGeneralSettings(state),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Sub-tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabButton(0, 'Location & OCR Scan'),
                    const SizedBox(width: 8),
                    _buildTabButton(1, 'Entry categories'),
                    const SizedBox(width: 8),
                    _buildTabButton(2, 'Shift timings & Approvals'),
                    const SizedBox(width: 8),
                    _buildTabButton(3, 'Database & Testing'),
                    const SizedBox(width: 8),
                    _buildTabButton(4, 'App Version & APK Releases'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tab Body
              if (_selectedSettingsTab == 0) _buildLocationAndScanTab(state),
              if (_selectedSettingsTab == 1) _buildEntryCategoriesTab(state),
              if (_selectedSettingsTab == 2) _buildShiftTimingsTab(state),
              if (_selectedSettingsTab == 3) _buildDatabaseTestingTab(state),
              if (_selectedSettingsTab == 4) _buildAppVersionTab(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButton(int idx, String title) {
    bool isSelected = _selectedSettingsTab == idx;
    return InkWell(
      onTap: () => setState(() => _selectedSettingsTab = idx),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? StationColors.primaryLight.withOpacity(0.12) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? StationColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? StationColors.primary : StationColors.textMedium,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // --- TAB 0: Location & OCR Scan ---
  Widget _buildLocationAndScanTab(StationStateProvider state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;

        Widget locationCard = Container(
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
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Station location & perimeter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('Configure GPS coordinates and valid scanning radius.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_location_alt_rounded, size: 16, color: Colors.white),
                    label: const Text('Edit Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.primary,
                      minimumSize: const Size(44, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showEditLocationDialog(context, state),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _stationNameController,
                maxLength: 30,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                decoration: InputDecoration(
                  labelText: 'Station Name / Location Address *',
                  hintText: 'e.g. Chatrai, Andhra Pradesh',
                  prefixIcon: const Icon(Icons.location_on, color: StationColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      maxLength: 15,
                      inputFormatters: [LengthLimitingTextInputFormatter(15)],
                      decoration: InputDecoration(
                        labelText: 'Latitude (°N) *',
                        hintText: '16.5062',
                        prefixIcon: const Icon(Icons.my_location_rounded, size: 18, color: StationColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      maxLength: 15,
                      inputFormatters: [LengthLimitingTextInputFormatter(15)],
                      decoration: InputDecoration(
                        labelText: 'Longitude (°E) *',
                        hintText: '80.6480',
                        prefixIcon: const Icon(Icons.explore_rounded, size: 18, color: StationColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Presets: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.textMedium)),
                    ActionChip(
                      avatar: const Icon(Icons.local_gas_station, size: 14, color: StationColors.primary),
                      label: const Text('Chatrai Forecourt (16.5062, 80.6480)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setState(() {
                          _stationNameController.text = 'Chatrai, Andhra Pradesh';
                          _latitudeController.text = '16.5062';
                          _longitudeController.text = '80.6480';
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.alt_route, size: 14, color: StationColors.primary),
                      label: const Text('Chatrai Bypass (16.5085, 80.6495)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setState(() {
                          _stationNameController.text = 'Chatrai Bypass Road';
                          _latitudeController.text = '16.5085';
                          _longitudeController.text = '80.6495';
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Map Preview
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.map_outlined, size: 80, color: Colors.blueGrey.withOpacity(0.2)),
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: StationColors.primary.withOpacity(0.12),
                        border: Border.all(color: StationColors.primary, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_gas_station, color: StationColors.primary, size: 28),
                          Text('${_radius.toInt()} m', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: StationColors.primary)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '${_latitudeController.text}° N, ${_longitudeController.text}° E',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Map preview (illustrative)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Station radius: ${_radius.toInt()} m',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Slider(
                value: _radius,
                min: 100,
                max: 200,
                divisions: 10,
                label: '${_radius.toInt()} m',
                activeColor: StationColors.primary,
                onChanged: (val) => setState(() => _radius = val),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('100 m', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('150 m', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('200 m', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                    label: const Text('Save Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.successGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _saveGeneralSettings(state),
                  ),
                ],
              ),
            ],
          ),
        );

        Widget scanControlCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
            border: Border.all(color: StationColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OCR & Scanner Governance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Control scanner permissions and physical presence rules.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
              const SizedBox(height: 16),

              // Setting 1: Allow staff to take totaliser photo
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: StationColors.primary,
                title: const Text('Allow staff to capture totaliser photo (OCR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('When disabled by Owner/Admin, shift staff are prevented from taking camera photos of the pump totaliser.', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                value: _allowStaffTotaliserScan,
                onChanged: (val) => setState(() => _allowStaffTotaliserScan = val),
              ),
              const Divider(height: 24),

              // Setting 2: Check location before scan
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: StationColors.primary,
                title: const Text('Check location before each scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Staff scanning is only permitted within station geofence radius.', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                value: _checkLocation,
                onChanged: (val) => setState(() => _checkLocation = val),
              ),
              const Divider(height: 24),

              // Setting 2b: Feature Flag for Live Shift-Only Location Tracking
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: StationColors.primary,
                title: const Text('Live user location tracking during active shift (Feature Flag)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Track user GPS location and location name only after their shift starts and automatically stop when the shift is closed.', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                value: _enableLiveLocationTracking,
                onChanged: (val) {
                  setState(() => _enableLiveLocationTracking = val);
                  final updated = state.settings.copyWith(enableLiveLocationTracking: val);
                  state.updateSettings(updated);
                },
              ),
              const Divider(height: 24),

              // Setting 3: Feature Flag for OCR Diagnostics Bug Icon Visibility
              const Text('OCR Diagnostics Debug Icon Visibility (Feature Flag)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Control who can see the orange bug report icon beside "Capture Photo" on the scan screen.', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _ocrDebugAccess,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.bug_report_outlined, color: StationColors.accentOrange),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'everyone',
                    child: Text('Visible to Everyone (Staff, Managers & Owners)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'owner_only',
                    child: Text('Owners & Managers Only (Hidden for Staff)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'disabled',
                    child: Text('Disabled / Completely Hidden', overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _ocrDebugAccess = val);
                    final updated = state.settings.copyWith(ocrDebugIconAccess: val);
                    state.updateSettings(updated);
                  }
                },
              ),
              const Divider(height: 24),

              const Text('Language preference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(
                        value: 'te',
                        groupValue: _defaultLang,
                        onChanged: (val) => setState(() => _defaultLang = val!),
                      ),
                      const Text('Telugu (తెలుగు)', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(
                        value: 'en',
                        groupValue: _defaultLang,
                        onChanged: (val) => setState(() => _defaultLang = val!),
                      ),
                      const Text('English', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );

        if (!isWide) {
          return Column(
            children: [
              locationCard,
              const SizedBox(height: 20),
              scanControlCard,
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: locationCard),
                const SizedBox(width: 20),
                Expanded(flex: 5, child: scanControlCard),
              ],
            ),
          ],
        );
      },
    );
  }

  // --- TAB 1: Dynamic Entry Categories CRUD ---
  Widget _buildEntryCategoriesTab(StationStateProvider state) {
    final categories = state.settings.categories;

    return Container(
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
                  const Text('Entry categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text('Dynamic categories for transaction entries. ${categories.length} total.', style: const TextStyle(fontSize: 12, color: StationColors.textMedium)),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('+ Add category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StationColors.primary,
                  minimumSize: const Size(140, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showAddCategoryDialog(context, state),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final cat = categories[idx];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                leading: Switch(
                  value: cat.enabled,
                  activeColor: StationColors.primary,
                  onChanged: (val) {
                    state.updateCategory(cat.copyWith(enabled: val));
                  },
                ),
                title: Text(
                  cat.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: cat.enabled ? StationColors.textDark : Colors.grey,
                  ),
                ),
                subtitle: cat.subtitle.isNotEmpty
                    ? Text(cat.subtitle, style: const TextStyle(fontSize: 12, color: StationColors.textMedium))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: StationColors.primary),
                      tooltip: 'Edit category',
                      onPressed: () => _showEditCategoryDialog(context, state, cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: StationColors.errorRed),
                      tooltip: 'Delete category',
                      onPressed: () => _showDeleteCategoryAlert(context, state, cat),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, StationStateProvider state) {
    final nameCtrl = TextEditingController();
    final subCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Entry Category', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              maxLength: 30,
              inputFormatters: [LengthLimitingTextInputFormatter(30)],
              decoration: const InputDecoration(labelText: 'Category Name (e.g. Toll / Generator)', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subCtrl,
              maxLength: 30,
              inputFormatters: [LengthLimitingTextInputFormatter(30)],
              decoration: const InputDecoration(labelText: 'Subtitle / Notes (optional)', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                final newCat = CategoryItem(
                  id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  subtitle: subCtrl.text.trim(),
                  enabled: true,
                );
                state.addCategory(newCat);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category "${newCat.name}" added successfully.')),
                );
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, StationStateProvider state, CategoryItem cat) {
    final nameCtrl = TextEditingController(text: cat.name);
    final subCtrl = TextEditingController(text: cat.subtitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              maxLength: 30,
              inputFormatters: [LengthLimitingTextInputFormatter(30)],
              decoration: const InputDecoration(labelText: 'Category Name', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subCtrl,
              maxLength: 30,
              inputFormatters: [LengthLimitingTextInputFormatter(30)],
              decoration: const InputDecoration(labelText: 'Subtitle / Notes', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                final updated = cat.copyWith(
                  name: nameCtrl.text.trim(),
                  subtitle: subCtrl.text.trim(),
                );
                state.updateCategory(updated);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Category "${updated.name}" updated.')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryAlert(BuildContext context, StationStateProvider state, CategoryItem cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: StationColors.errorRed),
            SizedBox(width: 8),
            Expanded(
              child: Text('Delete Category?', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete category "${cat.name}"?\n\nThis will remove it from all shift entry options.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.errorRed),
            onPressed: () {
              state.deleteCategory(cat.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Category "${cat.name}" deleted.')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: Shift Timings & Approvals ---
  Widget _buildShiftTimingsTab(StationStateProvider state) {
    final shiftTimings = state.settings.shiftTimings;
    final requests = state.timingRequests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timings Card with Add, Edit & Delete Shifts
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
                      const Text('Standard Shift Timings (Firestore Synchronized)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Configure active hours for Morning, Evening, and custom station shifts. ${shiftTimings.length} total shifts.', style: const TextStyle(fontSize: 12, color: StationColors.textMedium)),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('+ Add Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.primary,
                      minimumSize: const Size(130, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showAddShiftTimingDialog(context, state),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              if (shiftTimings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No shifts configured. Tap "+ Add Shift" to create your first shift.', style: TextStyle(color: StationColors.textMedium, fontSize: 13)),
                  ),
                )
              else
                ...shiftTimings.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, size: 18, color: StationColors.primary),
                            const SizedBox(width: 10),
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(entry.value, style: const TextStyle(fontSize: 14, color: StationColors.textDark, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: StationColors.primary),
                              tooltip: 'Edit shift',
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              onPressed: () => _showEditTimingDialog(context, state, entry.key, entry.value),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: StationColors.errorRed),
                              tooltip: 'Delete shift',
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              onPressed: () => _showDeleteShiftTimingAlert(context, state, entry.key),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Staff Timing Requests Card
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
              const Text('Staff Timing Selection & Approval Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Requests submitted by staff members upon login requiring manager/owner approval.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
              const SizedBox(height: 16),

              if (requests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: StationColors.divider),
                  ),
                  child: const Center(
                    child: Text('No pending shift timing requests from staff.', style: TextStyle(color: StationColors.textMedium, fontSize: 13)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final req = requests[idx];
                    bool isPending = req.status == 'pending';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isPending ? Colors.amber[100] : Colors.green[100],
                                child: Icon(isPending ? Icons.pending_actions : Icons.check, size: 18, color: isPending ? Colors.amber[800] : Colors.green[800]),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${req.staffName} → ${req.requestedShift} (${req.timingRange})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(req.reason.isNotEmpty ? 'Reason: ${req.reason}' : 'Status: ${req.status.toUpperCase()}', style: const TextStyle(fontSize: 12, color: StationColors.textMedium)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (isPending)
                            Wrap(
                              spacing: 8,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: StationColors.successGreen,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: const Size(60, 34),
                                  ),
                                  onPressed: () {
                                    state.approveShiftTiming(req.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Approved shift change for ${req.staffName}.')),
                                    );
                                  },
                                  child: const Text('Approve', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: const Size(60, 34),
                                  ),
                                  onPressed: () {
                                    state.rejectShiftTiming(req.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Rejected request from ${req.staffName}.')),
                                    );
                                  },
                                  child: const Text('Reject', style: TextStyle(fontSize: 12, color: StationColors.errorRed)),
                                ),
                              ],
                            )
                          else
                            Chip(
                              label: Text(req.status.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              backgroundColor: req.status == 'approved' ? Colors.green[50] : Colors.red[50],
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddShiftTimingDialog(BuildContext context, StationStateProvider state) {
    final nameCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '6:00 AM - 2:00 PM');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.more_time_rounded, color: StationColors.primary),
              SizedBox(width: 8),
              Text('Add New Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  maxLength: 30,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: const InputDecoration(
                    labelText: 'Shift Name * (e.g. Night, General)',
                    prefixIcon: Icon(Icons.schedule_rounded),
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeCtrl,
                  maxLength: 30,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: const InputDecoration(
                    labelText: 'Timing Range * (e.g. 10:00 PM - 6:00 AM)',
                    prefixIcon: Icon(Icons.access_time_rounded),
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Quick Timing Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.textMedium)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('6:00 AM - 2:00 PM', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() => timeCtrl.text = '6:00 AM - 2:00 PM'),
                    ),
                    ActionChip(
                      label: const Text('2:00 PM - 10:00 PM', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() => timeCtrl.text = '2:00 PM - 10:00 PM'),
                    ),
                    ActionChip(
                      label: const Text('10:00 PM - 6:00 AM', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() => timeCtrl.text = '10:00 PM - 6:00 AM'),
                    ),
                    ActionChip(
                      label: const Text('9:00 AM - 5:00 PM', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() => timeCtrl.text = '9:00 AM - 5:00 PM'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final range = timeCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a shift name.')),
                  );
                  return;
                }
                if (range.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter timing range.')),
                  );
                  return;
                }
                state.addShiftTiming(name, range);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Shift "$name" added successfully and synced to Firestore!'),
                    backgroundColor: StationColors.successGreen,
                  ),
                );
              },
              child: const Text('Add Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTimingDialog(BuildContext context, StationStateProvider state, String currentShiftName, String currentRange) {
    final nameCtrl = TextEditingController(text: currentShiftName);
    final timeCtrl = TextEditingController(text: currentRange);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Shift "$currentShiftName"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  maxLength: 30,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: const InputDecoration(
                    labelText: 'Shift Name *',
                    prefixIcon: Icon(Icons.schedule_rounded),
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeCtrl,
                  maxLength: 30,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: const InputDecoration(
                    labelText: 'Timing Range *',
                    prefixIcon: Icon(Icons.access_time_rounded),
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Quick Timing Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.textMedium)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('6:00 AM - 2:00 PM', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() => timeCtrl.text = '6:00 AM - 2:00 PM'),
                    ),
                    ActionChip(
                      label: const Text('2:00 PM - 10:00 PM', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() => timeCtrl.text = '2:00 PM - 10:00 PM'),
                    ),
                    ActionChip(
                      label: const Text('10:00 PM - 6:00 AM', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() => timeCtrl.text = '10:00 PM - 6:00 AM'),
                    ),
                    ActionChip(
                      label: const Text('9:00 AM - 5:00 PM', style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() => timeCtrl.text = '9:00 AM - 5:00 PM'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final newRange = timeCtrl.text.trim();
                if (newName.isEmpty || newRange.isEmpty) return;
                state.editShiftTiming(currentShiftName, newName, newRange);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Shift updated to "$newName" ($newRange) and saved to Firestore!'),
                    backgroundColor: StationColors.successGreen,
                  ),
                );
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteShiftTimingAlert(BuildContext context, StationStateProvider state, String shiftName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: StationColors.errorRed),
            SizedBox(width: 8),
            Text('Delete Shift?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete shift "$shiftName"?\n\nThis will remove it from all shift entry options, timing records, and staff schedules across all devices.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.errorRed),
            onPressed: () {
              state.deleteShiftTiming(shiftName);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Shift "$shiftName" deleted from Firestore.')),
              );
            },
            child: const Text('Delete Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: Database & Security Settings ---
  Widget _buildDatabaseActionCard({
    required bool isMobile,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    Color titleColor = StationColors.textDark,
    required String subtitle,
    required Widget actionButton,
  }) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: iconColor, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, height: 1.35, color: StationColors.textMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: actionButton,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: StationColors.textMedium),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          actionButton,
        ],
      ),
    );
  }

  Widget _buildDatabaseTestingTab(StationStateProvider state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 620;

        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
            border: Border.all(color: StationColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Station Security & Cloud Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              const Text('Manage biometric login, sample use-case data, and central cloud records for RFS (Chatrai).', style: TextStyle(fontSize: 13, color: StationColors.textMedium)),
              const SizedBox(height: 20),

              // Security Action: Biometric Authentication (Fingerprint & Face)
              _buildDatabaseActionCard(
                isMobile: isMobile,
                bgColor: const Color(0xFFF7FDF9),
                borderColor: StationColors.primary.withOpacity(0.2),
                icon: Icons.fingerprint,
                iconColor: StationColors.primary,
                title: 'Biometric Authentication (Fingerprint & Face ID)',
                subtitle: 'Enable one-touch secure biometric login on this device for ${state.currentUser.name} (${state.currentUser.role.displayName}).',
                actionButton: ElevatedButton.icon(
                  icon: const Icon(Icons.security, size: 16, color: Colors.white),
                  label: const Text('Enable on Device', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StationColors.primary,
                    minimumSize: const Size(150, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final supported = await BiometricService.isBiometricsSupported();
                    if (!supported) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Biometric hardware is not available on this device or platform.'),
                          backgroundColor: StationColors.warningAmber,
                        ),
                      );
                      return;
                    }
                    final ok = await BiometricService.enableBiometricLogin(state.currentUser.id);
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Biometric login enabled successfully for ${state.currentUser.name}!'),
                          backgroundColor: StationColors.successGreen,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Biometric approval was not completed.')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Action 1: Sync Data to Cloud
              _buildDatabaseActionCard(
                isMobile: isMobile,
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
                icon: Icons.cloud_upload_rounded,
                iconColor: StationColors.successGreen,
                title: 'Sync Authoritative Records to Cloud',
                subtitle: 'Pushes station doc, owners, managers, staff, pumps, nozzles, and settings to the central station cloud database.',
                actionButton: ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                  label: const Text('Sync to Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StationColors.successGreen,
                    minimumSize: const Size(150, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isProcessingAction
                      ? null
                      : () async {
                          setState(() => _isProcessingAction = true);
                          final msg = await state.seedAuthoritativeDataToFirestore();
                          setState(() => _isProcessingAction = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                    content: Text(msg),
                    duration: const Duration(seconds: 10),
                    backgroundColor: msg.contains('INCOMPLETE')
                        ? StationColors.errorRed
                        : StationColors.successGreen,
                  ),
                            );
                          }
                        },
                ),
              ),
              const SizedBox(height: 16),

              // Action 1B: Seed Sample Use-Case Dataset (Users, Money Entries, Pump Scans & Owner Reports)
              _buildDatabaseActionCard(
                isMobile: isMobile,
                bgColor: const Color(0xFFF0F9FF),
                borderColor: const Color(0xFFBAE6FD),
                icon: Icons.science_rounded,
                iconColor: const Color(0xFF0284C7),
                title: 'Load Sample Use-Case Data (Users, Entries & Reports)',
                titleColor: const Color(0xFF0369A1),
                subtitle: 'Populates realistic station users (Owners, Managers, Staff), Pump 1 & Pump 2 nozzle readings, PhonePe/Card/Cash/Credit/Expense/Handover entries, and Owner Daily Reports.',
                actionButton: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_graph_rounded, size: 16, color: Colors.white),
                  label: const Text('Load Sample Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    minimumSize: const Size(150, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isProcessingAction
                      ? null
                      : () async {
                          setState(() => _isProcessingAction = true);
                          final msg = await state.seedSampleUseCaseDataToFirestore();
                          setState(() => _isProcessingAction = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                    content: Text(msg),
                    duration: const Duration(seconds: 10),
                    backgroundColor: msg.contains('INCOMPLETE')
                        ? StationColors.errorRed
                        : StationColors.successGreen,
                  ),
                            );
                          }
                        },
                ),
              ),
              const SizedBox(height: 16),

              // Action 2: Clear Collections with single-click and confirmation alert
              _buildDatabaseActionCard(
                isMobile: isMobile,
                bgColor: const Color(0xFFFEF2F2),
                borderColor: const Color(0xFFFECACA),
                icon: Icons.delete_sweep_rounded,
                iconColor: StationColors.errorRed,
                title: 'Reset Operational Records (Single-Click Clean Reset)',
                titleColor: StationColors.errorRed,
                subtitle: 'Purges all transaction entries, totaliser scans, credit khata, shift handovers, notifications, and resets today\'s dispenser readings to 0.0 L across local & cloud storage.',
                actionButton: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, size: 16, color: Colors.white),
                  label: const Text('Clear Records', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StationColors.errorRed,
                    minimumSize: const Size(150, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isProcessingAction
                      ? null
                      : () => _confirmClearCollections(context, state),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearCollections(BuildContext context, StationStateProvider state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: StationColors.errorRed),
            SizedBox(width: 8),
            Expanded(
              child: Text('Clear All Operational Data?', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to purge all operational records?\n\nThis will clear money entries, totaliser scans, credit khata balances, notifications, shift handovers, and reset today\'s dispenser nozzle readings to 0.0 L.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isProcessingAction = true);
              final msg = await state.clearAllFirestoreCollections();
              setState(() => _isProcessingAction = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    duration: const Duration(seconds: 10),
                    backgroundColor: msg.contains('INCOMPLETE')
                        ? StationColors.errorRed
                        : StationColors.successGreen,
                  ),
                );
              }
            },
            child: const Text('Yes, Purge Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: App Version & APK Force Update Management ---
  Widget _buildAppVersionTab(StationStateProvider state) {
    final installedVer = AppVersionService.version;
    final installedBuild = AppVersionService.buildNumber;
    final targetVer = state.settings.latestVersion;
    final targetBuild = state.settings.latestBuildNumber;
    final isNewer = AppVersionService.isRemoteNewer(targetVer, targetBuild, installedVer, installedBuild);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const OtaDiagnostics(),
        // Card 1: Installed App Version & Device Status
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
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_android_rounded, color: StationColors.primary, size: 22),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Installed App Version on this Device',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isNewer ? StationColors.accentOrangeLight : StationColors.successBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isNewer ? StationColors.accentOrange : StationColors.successGreen),
                    ),
                    child: Text(
                      isNewer ? 'Update Available' : 'Running Latest ✓',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isNewer ? StationColors.accentOrange : StationColors.successGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildStatPill('Installed Version', 'v$installedVer+$installedBuild'),
                  _buildStatPill('Cloud Target Version', 'v$targetVer+$targetBuild'),
                  _buildStatPill('Platform', Theme.of(context).platform.name),
                  _buildStatPill('Force Update Policy', state.settings.forceUpdate ? 'Active (Strict)' : 'Optional'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Card 1B: Per-User App Version Tracker
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
              const Row(
                children: [
                  Icon(Icons.group_outlined, color: StationColors.primary, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Station Users App Version Tracker (Every User)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tracks the exact app version and platform last used by each station owner, manager, and shift staff member.',
                style: TextStyle(fontSize: 12, color: StationColors.textMedium),
              ),
              const SizedBox(height: 14),
              ...state.allUsers.map((u) {
                final hasVer = u.appVersion.isNotEmpty;
                final isOnline = state.isUserOnline(u.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: StationColors.divider),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: StationColors.primary.withOpacity(0.12),
                            child: Text(
                              u.name.isNotEmpty ? u.name[0] : 'U',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.primary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      state.isSelfUser(u) ? '${u.name} (Self)' : u.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    if (state.isSelfUser(u))
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: StationColors.primary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Self',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    if (isOnline)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('● Online', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green[800])),
                                      ),
                                  ],
                                ),
                                Text(
                                  '${u.role.displayName} • ${u.phoneNumber}${u.assignedShift != null ? " • ${u.assignedShift} Shift" : ""}',
                                  style: const TextStyle(fontSize: 11, color: StationColors.textMedium),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasVer ? StationColors.primary.withOpacity(0.1) : Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: hasVer ? StationColors.primary.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              hasVer ? u.appVersion : 'Not logged in yet',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: hasVer ? StationColors.primary : StationColors.accentOrange,
                              ),
                            ),
                          ),
                          if (u.lastSeenAt != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Last active: ${DateFormatter.formatDateTimeIST(u.lastSeenAt!)}',
                              style: const TextStyle(fontSize: 10, color: StationColors.textLight),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Card 2: Cloud Version & Force Update Management Form
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
              const Row(
                children: [
                  Icon(Icons.cloud_sync_rounded, color: StationColors.accentOrange, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cloud Version & APK Distribution (Firebase Authoritative)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Configure the required version and APK download link in Cloud Firestore. When Force Update is active, any staff or manager device running an older version is immediately blocked and guided to download the new APK.',
                style: TextStyle(fontSize: 12, height: 1.4, color: StationColors.textMedium),
              ),
              const SizedBox(height: 18),

              // Inputs: Target Version & Build Number (Responsive stack on mobile)
              LayoutBuilder(
                builder: (context, inputConstraints) {
                  final stackInputs = inputConstraints.maxWidth < 500;
                  final versionField = TextField(
                    controller: _targetVersionController,
                    onChanged: (val) {
                      final ver = val.trim();
                      final build = int.tryParse(_targetBuildNumberController.text.trim()) ?? state.settings.latestBuildNumber;
                      if (_updateUrlController.text.isEmpty ||
                          _updateUrlController.text.contains('/static/reya-filling-station')) {
                        _updateUrlController.text = AppVersionService.defaultHostedApkUrl(ver, build);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Target Release Version (e.g. 1.0.27)',
                      prefixIcon: const Icon(Icons.tag),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                  final buildField = TextField(
                    controller: _targetBuildNumberController,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final ver = _targetVersionController.text.trim();
                      final build = int.tryParse(val.trim()) ?? state.settings.latestBuildNumber;
                      if (_updateUrlController.text.isEmpty ||
                          _updateUrlController.text.contains('/static/reya-filling-station')) {
                        _updateUrlController.text = AppVersionService.defaultHostedApkUrl(ver, build);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Target Build Number (e.g. 28)',
                      prefixIcon: const Icon(Icons.build_circle_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );

                  if (stackInputs) {
                    return Column(
                      children: [
                        versionField,
                        const SizedBox(height: 12),
                        buildField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: versionField),
                      const SizedBox(width: 16),
                      Expanded(child: buildField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // APK Download URL
              TextField(
                controller: _updateUrlController,
                decoration: InputDecoration(
                  labelText: 'APK Download Link / URL (Versioned)',
                  hintText: 'https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.27+28.apk',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              // Force Update Switch
              SwitchListTile(
                title: const Text('Force Update Required (Block older app versions)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('When enabled, devices running a version lower than target cannot dismiss the update dialog.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
                value: _forceUpdate,
                activeColor: StationColors.accentOrange,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _forceUpdate = val),
              ),
              const SizedBox(height: 12),

              // Release Notes Input
              TextField(
                controller: _releaseNotesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Release Notes (Shown to staff/managers during update)',
                  hintText: 'e.g. Added camera slip capture, biometric quick login, and persistent session support.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.white),
                    label: const Text('Upload & Register APK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      minimumSize: const Size(190, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showUploadApkDialog(context, state),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                    label: const Text('Share APK Link', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      minimumSize: const Size(160, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showShareApkDialog(context, state),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_done_rounded, size: 18, color: Colors.white),
                    label: const Text('Save Policy to Cloud', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.primary,
                      minimumSize: const Size(170, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _saveVersionSettings(state),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 18, color: StationColors.accentOrange),
                    label: const Text('Preview Force Update Dialog', style: TextStyle(fontWeight: FontWeight.bold, color: StationColors.accentOrange)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: StationColors.accentOrange),
                      minimumSize: const Size(180, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final ver = _targetVersionController.text.trim();
                      final build = int.tryParse(_targetBuildNumberController.text.trim()) ?? 20;
                      final previewSettings = state.settings.copyWith(
                        latestVersion: ver,
                        latestBuildNumber: build,
                        updateUrl: _getAbsoluteApkUrl(_updateUrlController.text.trim(), version: ver, buildNumber: build),
                        forceUpdate: _forceUpdate,
                        releaseNotes: _releaseNotesController.text.trim(),
                      );
                      ForceUpdateDialog.show(context, previewSettings, previewMode: true);
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 18, color: StationColors.primary),
                    label: const Text('Test Download APK Link', style: TextStyle(fontWeight: FontWeight.bold, color: StationColors.primary)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: StationColors.primary),
                      minimumSize: const Size(160, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final ver = _targetVersionController.text.trim();
                      final build = int.tryParse(_targetBuildNumberController.text.trim()) ?? state.settings.latestBuildNumber;
                      final fullUrl = _getAbsoluteApkUrl(_updateUrlController.text.trim(), version: ver, buildNumber: build);
                      AppVersionService.launchDownload(fullUrl, version: ver, buildNumber: build);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Card 3: Cloud APK Releases History
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
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, color: StationColors.primary, size: 22),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Published APK Releases in Firestore',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.auto_delete_outlined, size: 14, color: StationColors.errorRed),
                        label: const Text('Delete > 7 Days Old', style: TextStyle(color: StationColors.errorRed, fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: StationColors.errorRed),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(130, 32),
                        ),
                        onPressed: () => _confirmPurgeOldReleases(context, state),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF16A34A)),
                        label: const Text('Share Latest', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                        onPressed: () => _showShareApkDialog(context, state),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Audit history of Android APK binaries registered in Firestore. Staff and managers can download or verify these builds.',
                style: TextStyle(fontSize: 12, color: StationColors.textMedium),
              ),
              const SizedBox(height: 16),
              if (state.apkReleases.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: StationColors.divider),
                  ),
                  child: Wrap(
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: StationColors.primaryLight.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('v${state.settings.latestVersion}+${state.settings.latestBuildNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: StationColors.primary)),
                              ),
                              Text(
                                'reya-filling-station-v${state.settings.latestVersion}+${state.settings.latestBuildNumber}.apk',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Authoritative Hosting Link: ${_getAbsoluteApkUrl(state.settings.updateUrl, version: state.settings.latestVersion, buildNumber: state.settings.latestBuildNumber)}',
                            style: const TextStyle(fontSize: 11, color: StationColors.textMedium),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 14, color: Colors.white),
                        label: const Text('Share', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(70, 36),
                        ),
                        onPressed: () => _showShareApkDialog(context, state),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.apkReleases.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final rel = state.apkReleases[idx];
                    final versionedLink = _getAbsoluteApkUrl(rel.downloadUrl, version: rel.version, buildNumber: rel.buildNumber);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: StationColors.primaryLight.withOpacity(0.15),
                        child: const Icon(Icons.android_rounded, color: StationColors.primary),
                      ),
                      title: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(rel.displayVersion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(rel.formattedSize, style: const TextStyle(fontSize: 10, color: StationColors.textMedium)),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Published: ${rel.formattedPublishedAt} by ${rel.publishedBy}', style: const TextStyle(fontSize: 11, color: StationColors.textMedium)),
                          Text('Link: $versionedLink', style: const TextStyle(fontSize: 11, color: StationColors.primary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (rel.releaseNotes.isNotEmpty)
                            Text(rel.releaseNotes, style: const TextStyle(fontSize: 11, color: StationColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF16A34A)),
                            tooltip: 'Share APK link',
                            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                            padding: EdgeInsets.zero,
                            onPressed: () => _showShareApkDialog(context, state, rel),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_rounded, size: 18, color: StationColors.primary),
                            tooltip: 'Download APK',
                            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                            padding: EdgeInsets.zero,
                            onPressed: () => AppVersionService.launchDownload(
                              versionedLink,
                              version: rel.version,
                              buildNumber: rel.buildNumber,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: StationColors.errorRed),
                            tooltip: 'Delete release record',
                            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                            padding: EdgeInsets.zero,
                            onPressed: () => _confirmDeleteRelease(context, state, rel),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _getAbsoluteApkUrl(String rawUrl, {String? version, int? buildNumber}) {
    final ver = (version != null && version.trim().isNotEmpty)
        ? version.trim()
        : (_targetVersionController.text.trim().isNotEmpty
            ? _targetVersionController.text.trim()
            : AppVersionService.fallbackVersion);
    final build = buildNumber ??
        int.tryParse(_targetBuildNumberController.text.trim()) ??
        AppVersionService.fallbackBuildNumber;
    final clean = rawUrl.trim();
    if (clean.isEmpty || clean.contains('/static/reya-filling-station')) {
      return AppVersionService.defaultHostedApkUrl(ver, build);
    }
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    if (clean.startsWith('/')) {
      return 'https://reya-filling-station-chatrai.web.app$clean';
    }
    return 'https://reya-filling-station-chatrai.web.app/$clean';
  }

  void _showUploadApkDialog(BuildContext context, StationStateProvider state) {
    final verCtrl = TextEditingController(text: _targetVersionController.text.trim());
    final buildCtrl = TextEditingController(text: _targetBuildNumberController.text.trim());
    final initVer = verCtrl.text.isNotEmpty ? verCtrl.text : state.settings.latestVersion;
    final initBuild = int.tryParse(buildCtrl.text) ?? state.settings.latestBuildNumber;
    final urlCtrl = TextEditingController(
      text: _getAbsoluteApkUrl(_updateUrlController.text.trim(), version: initVer, buildNumber: initBuild),
    );
    final notesCtrl = TextEditingController(text: _releaseNotesController.text.trim());
    int selectedSourceType = 0; // 0 = Official Hosting Link, 1 = Custom URL

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_upload_rounded, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Upload & Register APK in Firestore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How APK Binary Storage Works',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0369A1)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '• Cloud Firestore stores release metadata, version tags, and the public versioned download link.\n'
                              '• Android APK binary files (~90MB) are hosted on Firebase Hosting CDN.\n'
                              '• Each release link includes the version (e.g. reya-filling-station-v1.0.19+20.apk) so browsers never serve a cached older APK.',
                              style: TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF0C4A6E)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: verCtrl,
                        maxLength: 30,
                        inputFormatters: [LengthLimitingTextInputFormatter(30)],
                        onChanged: (v) {
                          if (selectedSourceType == 0) {
                            final b = int.tryParse(buildCtrl.text.trim()) ?? initBuild;
                            setDialogState(() {
                              urlCtrl.text = AppVersionService.defaultHostedApkUrl(v.trim(), b);
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Version * (e.g. 1.0.19)',
                          prefixIcon: Icon(Icons.tag),
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: buildCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        inputFormatters: [LengthLimitingTextInputFormatter(10)],
                        onChanged: (bStr) {
                          if (selectedSourceType == 0) {
                            final b = int.tryParse(bStr.trim()) ?? initBuild;
                            setDialogState(() {
                              urlCtrl.text = AppVersionService.defaultHostedApkUrl(verCtrl.text.trim(), b);
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Build Number * (e.g. 20)',
                          prefixIcon: Icon(Icons.build_circle_outlined),
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('APK Storage Link Source:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.textMedium)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Official Hosting Link (Versioned CDN)', style: TextStyle(fontSize: 11)),
                      selected: selectedSourceType == 0,
                      onSelected: (val) {
                        if (val) {
                          final b = int.tryParse(buildCtrl.text.trim()) ?? initBuild;
                          setDialogState(() {
                            selectedSourceType = 0;
                            urlCtrl.text = AppVersionService.defaultHostedApkUrl(verCtrl.text.trim(), b);
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Custom URL / Storage Link', style: TextStyle(fontSize: 11)),
                      selected: selectedSourceType == 1,
                      onSelected: (val) {
                        if (val) {
                          setDialogState(() => selectedSourceType = 1);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'APK Download URL (with Version) *',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                    hintText: 'https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.19+20.apk',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Release Notes (Displayed to Staff)',
                    prefixIcon: Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Dynamic shift timings CRUD, APK upload & WhatsApp sharing.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_done_rounded, size: 16, color: Colors.white),
              label: const Text('Publish to Firestore', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () async {
                final targetVer = verCtrl.text.trim();
                final targetBuild = int.tryParse(buildCtrl.text.trim()) ?? 20;
                final resolvedUrl = _getAbsoluteApkUrl(
                  urlCtrl.text.trim(),
                  version: targetVer,
                  buildNumber: targetBuild,
                );
                final notes = notesCtrl.text.trim();

                if (targetVer.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter version number.')),
                  );
                  return;
                }

                final release = ApkReleaseItem(
                  id: 'rel_${DateTime.now().millisecondsSinceEpoch}',
                  version: targetVer,
                  buildNumber: targetBuild,
                  downloadUrl: resolvedUrl,
                  fileName: 'reya-filling-station-v$targetVer+$targetBuild.apk',
                  fileSizeBytes: 92962818,
                  publishedBy: state.currentUser.name,
                  publishedAt: DateTime.now(),
                  releaseNotes: notes,
                  active: true,
                );

                await state.publishApkRelease(release);

                // Update text controllers in parent screen
                _targetVersionController.text = targetVer;
                _targetBuildNumberController.text = targetBuild.toString();
                _updateUrlController.text = resolvedUrl;
                _releaseNotesController.text = notes;

                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('APK v$targetVer+$targetBuild successfully published to Firestore!'),
                      backgroundColor: StationColors.successGreen,
                    ),
                  );
                  // Automatically prompt share link dialog for instant distribution
                  _showShareApkDialog(context, state, release);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShareApkDialog(BuildContext context, StationStateProvider state, [ApkReleaseItem? release]) {
    final ver = release?.version ?? state.settings.latestVersion;
    final build = release?.buildNumber ?? state.settings.latestBuildNumber;
    final rawUrl = release?.downloadUrl ?? _updateUrlController.text.trim();
    final fullUrl = _getAbsoluteApkUrl(rawUrl, version: ver, buildNumber: build);
    final notes = release?.releaseNotes ?? state.settings.releaseNotes;

    final shareText = '''
🚀 *Reya Filling Station App Update (v$ver+$build)*

Download and install the latest Android APK for staff & managers:
🔗 $fullUrl


📌 *What's New:*
$notes
'''.trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.share_rounded, color: Color(0xFF16A34A), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Share APK Link (v$ver+$build)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share this direct Android APK download link with pump staff, managers, and owners:', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
              const SizedBox(height: 14),

              // Download Link Preview Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Direct APK Download URL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: StationColors.textLight)),
                    const SizedBox(height: 4),
                    SelectableText(
                      fullUrl,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StationColors.primary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Copy URL', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(80, 32),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: fullUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('APK download link copied to clipboard!'), backgroundColor: StationColors.successGreen),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 14),
                          label: const Text('Download', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(80, 32),
                          ),
                          onPressed: () => AppVersionService.launchDownload(fullUrl),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // WhatsApp Share Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF16A34A)),
                        SizedBox(width: 6),
                        Text('WhatsApp Message Format', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      shareText,
                      style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF14532D)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                          label: const Text('Share on WhatsApp', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(130, 34),
                          ),
                          onPressed: () async {
                            final success = await UrlLauncherHelper.launchWhatsApp(shareText);
                            if (!success && context.mounted) {
                              Clipboard.setData(ClipboardData(text: shareText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not open WhatsApp app directly. Message copied to clipboard!'),
                                  backgroundColor: StationColors.accentOrange,
                                ),
                              );
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.content_copy_rounded, size: 14, color: Color(0xFF166534)),
                          label: const Text('Copy Message', style: TextStyle(fontSize: 12, color: Color(0xFF166534))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF16A34A)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(100, 34),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: shareText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Complete WhatsApp message copied to clipboard!'), backgroundColor: StationColors.successGreen),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StationColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: StationColors.textLight)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: StationColors.textDark)),
        ],
      ),
    );
  }

  Future<void> _saveVersionSettings(StationStateProvider state) async {
    final targetVer = _targetVersionController.text.trim();
    final targetBuild = int.tryParse(_targetBuildNumberController.text.trim()) ?? state.settings.latestBuildNumber;
    final resolvedUrl = _getAbsoluteApkUrl(
      _updateUrlController.text.trim(),
      version: targetVer,
      buildNumber: targetBuild,
    );
    _updateUrlController.text = resolvedUrl;
    final notes = _releaseNotesController.text.trim();

    final updated = state.settings.copyWith(
      latestVersion: targetVer,
      latestBuildNumber: targetBuild,
      updateUrl: resolvedUrl,
      forceUpdate: _forceUpdate,
      releaseNotes: notes,
    );
    state.updateSettings(updated);

    final release = ApkReleaseItem(
      id: 'rel_${targetVer.replaceAll('.', '_')}_$targetBuild',
      version: targetVer,
      buildNumber: targetBuild,
      downloadUrl: resolvedUrl,
      fileName: 'reya-filling-station-v$targetVer+$targetBuild.apk',
      fileSizeBytes: 92962818,
      publishedBy: state.currentUser.name,
      publishedAt: DateTime.now(),
      releaseNotes: notes,
      active: true,
    );
    await state.publishApkRelease(release, forceUpdateOverride: _forceUpdate);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('App v$targetVer+$targetBuild policy & update notification pushed to Cloud Firestore!'),
          backgroundColor: StationColors.successGreen,
        ),
      );
    }
  }

  void _confirmDeleteRelease(BuildContext context, StationStateProvider state, ApkReleaseItem rel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: StationColors.errorRed),
            SizedBox(width: 8),
            Text('Delete APK Release?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the release record for v${rel.version}+${rel.buildNumber}?\n\nThis will remove it from the Cloud Firestore APK releases catalog.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await state.deleteApkRelease(rel.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('APK release v${rel.version}+${rel.buildNumber} deleted.'),
                    backgroundColor: StationColors.errorRed,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmPurgeOldReleases(BuildContext context, StationStateProvider state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_delete_outlined, color: StationColors.errorRed),
            SizedBox(width: 8),
            Text('Purge Older Releases?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Delete all APK release records older than 7 days from Cloud Firestore?\n\nRecent releases will be preserved.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final count = await state.purgeApkReleasesOlderThan(const Duration(days: 7));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(count > 0
                        ? 'Successfully deleted $count release records older than 7 days.'
                        : 'No releases older than 7 days found.'),
                    backgroundColor: StationColors.successGreen,
                  ),
                );
              }
            },
            child: const Text('Purge Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
