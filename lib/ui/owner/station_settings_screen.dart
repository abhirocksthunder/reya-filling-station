import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../l10n/app_strings.dart';
import '../../models/station_settings.dart';
import '../../services/station_state_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/app_version_service.dart';
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
  late bool _allowStaffTotaliserScan;
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
    _allowStaffTotaliserScan = settings.allowStaffTotaliserCameraScan;
    _defaultLang = settings.defaultLanguage;

    _stationNameController = TextEditingController(text: settings.stationName);
    _latitudeController = TextEditingController(text: settings.latitude.toStringAsFixed(4));
    _longitudeController = TextEditingController(text: settings.longitude.toStringAsFixed(4));

    _targetVersionController = TextEditingController(text: settings.latestVersion);
    _targetBuildNumberController = TextEditingController(text: settings.latestBuildNumber.toString());
    _updateUrlController = TextEditingController(text: settings.updateUrl);
    _releaseNotesController = TextEditingController(text: settings.releaseNotes);
    _forceUpdate = settings.forceUpdate;
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
      allowStaffTotaliserCameraScan: _allowStaffTotaliserScan,
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
              Text('Edit Station Location & Perimeter'),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.get('stationSettings', lang),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Station location & perimeter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Configure GPS coordinates and valid scanning radius.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_location_alt_rounded, size: 16, color: Colors.white),
                    label: const Text('Edit Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.primary,
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

              const Text('Language preference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Radio<String>(
                    value: 'te',
                    groupValue: _defaultLang,
                    onChanged: (val) => setState(() => _defaultLang = val!),
                  ),
                  const Text('Telugu (తెలుగు)', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 16),
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

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: locationCard),
            const SizedBox(width: 20),
            Expanded(flex: 5, child: scanControlCard),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            Text('Delete Category?', style: TextStyle(fontWeight: FontWeight.bold)),
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
        // Timings Card
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
              const Text('Standard Shift Timings (Manager/Owner Configured)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Configure active hours for Morning, Evening, and Night shifts.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
              const SizedBox(height: 16),
              ...shiftTimings.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 18, color: StationColors.primary),
                          const SizedBox(width: 10),
                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Row(
                        children: [
                          Text(entry.value, style: const TextStyle(fontSize: 14, color: StationColors.textDark, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: StationColors.primary),
                            onPressed: () => _showEditTimingDialog(context, state, entry.key, entry.value),
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
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isPending ? Colors.amber[100] : Colors.green[100],
                        child: Icon(isPending ? Icons.pending_actions : Icons.check, color: isPending ? Colors.amber[800] : Colors.green[800]),
                      ),
                      title: Text('${req.staffName} → ${req.requestedShift} (${req.timingRange})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(req.reason.isNotEmpty ? 'Reason: ${req.reason}' : 'Status: ${req.status.toUpperCase()}', style: const TextStyle(fontSize: 12)),
                      trailing: isPending
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: StationColors.successGreen,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: const Size(60, 32),
                                  ),
                                  onPressed: () {
                                    state.approveShiftTiming(req.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Approved shift change for ${req.staffName}.')),
                                    );
                                  },
                                  child: const Text('Approve', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: const Size(60, 32),
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
                          : Chip(
                              label: Text(req.status.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              backgroundColor: req.status == 'approved' ? Colors.green[50] : Colors.red[50],
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

  void _showEditTimingDialog(BuildContext context, StationStateProvider state, String shiftName, String currentRange) {
    final ctrl = TextEditingController(text: currentRange);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $shiftName Shift Timing', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Time Range (e.g. 6:00 AM - 2:00 PM)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StationColors.primary),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                state.updateShiftTiming(shiftName, ctrl.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$shiftName timing updated to ${ctrl.text.trim()}')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: Database & Security Settings ---
  Widget _buildDatabaseTestingTab(StationStateProvider state) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          const Text('Manage biometric login and central cloud records for Reya Filling Station (Chatrai).', style: TextStyle(fontSize: 13, color: StationColors.textMedium)),
          const SizedBox(height: 24),

          // Security Action: Biometric Authentication (Fingerprint & Face)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FDF9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: StationColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fingerprint, color: StationColors.primary, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Biometric Authentication (Fingerprint & Face ID)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: StationColors.textDark)),
                      const SizedBox(height: 2),
                      Text('Enable one-touch secure biometric login on this device for ${state.currentUser.name} (${state.currentUser.role.displayName}).', style: const TextStyle(fontSize: 12, color: StationColors.textMedium)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.security, size: 16, color: Colors.white),
                  label: const Text('Enable on Device', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StationColors.primary,
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
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action 1: Sync Data to Cloud
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_upload_rounded, color: StationColors.successGreen, size: 36),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sync Authoritative Records to Cloud', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: StationColors.textDark)),
                      SizedBox(height: 2),
                      Text('Pushes station doc, Kalyan & Ranjit owners, pumps, nozzles, and settings to the central station cloud database.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                  label: const Text('Sync to Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StationColors.successGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isProcessingAction
                      ? null
                      : () async {
                          setState(() => _isProcessingAction = true);
                          final msg = await state.seedAuthoritativeDataToFirestore();
                          setState(() => _isProcessingAction = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg), backgroundColor: StationColors.successGreen),
                          );
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action 2: Clear Collections with single-click and confirmation alert
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.delete_sweep_rounded, color: StationColors.errorRed, size: 36),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reset Operational Records (Single-Click Clean Reset)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: StationColors.errorRed)),
                      SizedBox(height: 2),
                      Text('Clears test transaction entries, totaliser scans, and shift requests from the database so you can test clean states anytime.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, size: 16, color: Colors.white),
                  label: const Text('Clear Records', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StationColors.errorRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isProcessingAction
                      ? null
                      : () => _confirmClearCollections(context, state),
                ),
              ],
            ),
          ),
        ],
      ),
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
            Text('Clear Operational Records?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to purge operational records (entries, scan attempts, timing requests)?\n\nThis is useful for resetting test runs.',
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg)),
              );
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.phone_android_rounded, color: StationColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text('Installed App Version on this Device', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  Text('Cloud Version & APK Distribution (Firebase Authoritative)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Configure the required version and APK download link in Cloud Firestore. When Force Update is active, any staff or manager device running an older version is immediately blocked and guided to download the new APK.',
                style: TextStyle(fontSize: 12, height: 1.4, color: StationColors.textMedium),
              ),
              const SizedBox(height: 18),

              // Inputs Row: Target Version & Build Number
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetVersionController,
                      decoration: InputDecoration(
                        labelText: 'Target Release Version (e.g. 1.0.4)',
                        prefixIcon: const Icon(Icons.tag),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _targetBuildNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Target Build Number (e.g. 5)',
                        prefixIcon: const Icon(Icons.build_circle_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // APK Download URL
              TextField(
                controller: _updateUrlController,
                decoration: InputDecoration(
                  labelText: 'APK Download Link / URL',
                  hintText: 'http://<YOUR-PC-IP>:9000/static/reya-filling-station.apk or Firebase Storage URL',
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
                    icon: const Icon(Icons.cloud_upload_rounded, size: 18, color: Colors.white),
                    label: const Text('Save Version Policy to Cloud', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StationColors.primary,
                      minimumSize: const Size(180, 44),
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
                      final previewSettings = state.settings.copyWith(
                        latestVersion: _targetVersionController.text.trim(),
                        latestBuildNumber: int.tryParse(_targetBuildNumberController.text.trim()) ?? 3,
                        updateUrl: _updateUrlController.text.trim(),
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
                      AppVersionService.launchDownload(_updateUrlController.text.trim());
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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

  void _saveVersionSettings(StationStateProvider state) {
    final updated = state.settings.copyWith(
      latestVersion: _targetVersionController.text.trim(),
      latestBuildNumber: int.tryParse(_targetBuildNumberController.text.trim()) ?? 3,
      updateUrl: _updateUrlController.text.trim(),
      forceUpdate: _forceUpdate,
      releaseNotes: _releaseNotesController.text.trim(),
    );
    state.updateSettings(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App version policy and APK update link saved to Cloud Database!'),
        backgroundColor: StationColors.successGreen,
      ),
    );
  }
}
