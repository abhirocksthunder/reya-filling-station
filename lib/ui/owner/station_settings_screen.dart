import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../l10n/app_strings.dart';
import '../../models/station_settings.dart';
import '../../services/station_state_provider.dart';

class StationSettingsScreen extends StatefulWidget {
  const StationSettingsScreen({super.key});

  @override
  State<StationSettingsScreen> createState() => _StationSettingsScreenState();
}

class _StationSettingsScreenState extends State<StationSettingsScreen> {
  int _selectedSettingsTab = 0; // 0 = Location, 1 = Entry categories

  late double _radius;
  late bool _checkLocation;
  late Map<String, bool> _categories;
  late String _defaultLang;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<StationStateProvider>(context, listen: false).settings;
    _radius = settings.radiusMeters;
    _checkLocation = settings.checkLocationBeforeScan;
    _categories = Map.from(settings.enabledCategories);
    _defaultLang = settings.defaultLanguage;
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.get('stationSettings', lang),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: StationColors.textDark),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, size: 18, color: Colors.white),
                label: const Text('Save settings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StationColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final newSettings = state.settings.copyWith(
                    radiusMeters: _radius,
                    checkLocationBeforeScan: _checkLocation,
                    enabledCategories: _categories,
                    defaultLanguage: _defaultLang,
                  );
                  state.updateSettings(newSettings);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Station settings updated successfully.'),
                      backgroundColor: StationColors.successGreen,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Settings Sub-tabs
          Row(
            children: [
              _buildTabButton(0, 'Location'),
              const SizedBox(width: 12),
              _buildTabButton(1, 'Entry categories'),
            ],
          ),
          const SizedBox(height: 24),

          // Two-column Content
          LayoutBuilder(
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
                    const Text('Station location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('Choose your station location on the map.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
                    const SizedBox(height: 12),
                    TextField(
                      readOnly: true,
                      controller: TextEditingController(text: 'Chatrai, Andhra Pradesh (16.5062° N, 80.6480° E)'),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on, color: StationColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Map Preview with Circular Geofence
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
                          // Geofence Circle
                          Container(
                            width: 130,
                            height: 130,
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
                    // Radius Slider
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
                    const SizedBox(height: 16),
                    // Check Location Toggle
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Check location before each scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              const Text('Staff scanning is allowed inside station radius.', style: TextStyle(fontSize: 12, color: StationColors.textLight)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _checkLocation,
                          activeColor: StationColors.primary,
                          onChanged: (val) => setState(() => _checkLocation = val),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              Widget categoriesCard = Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(StationDimensions.cardRadius),
                  border: Border.all(color: StationColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Entry categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('Select which entry types are available.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
                    const SizedBox(height: 16),

                    _buildCategoryCheck('phonePe', 'PhonePe', subtitle: 'Required number: 10 digits'),
                    _buildCategoryCheck('cash', 'Cash'),
                    _buildCategoryCheck('card', 'Card'),
                    _buildCategoryCheck('credit', 'Credit'),
                    _buildCategoryCheck('expenses', 'Expenses'),
                    _buildCategoryCheck('salary', 'Salary'),
                    _buildCategoryCheck('cashToOwner', 'Cash to owner'),

                    const Divider(height: 28),
                    const Text('Language settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                    categoriesCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: locationCard),
                  const SizedBox(width: 20),
                  Expanded(flex: 5, child: categoriesCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int idx, String title) {
    bool isSelected = _selectedSettingsTab == idx;
    return InkWell(
      onTap: () => setState(() => _selectedSettingsTab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
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
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? StationColors.primary : StationColors.textMedium,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCheck(String key, String title, {String? subtitle}) {
    bool isChecked = _categories[key] ?? true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: isChecked,
            activeColor: StationColors.primary,
            onChanged: (val) {
              if (val != null) setState(() => _categories[key] = val);
            },
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (subtitle != null)
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: StationColors.textLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
