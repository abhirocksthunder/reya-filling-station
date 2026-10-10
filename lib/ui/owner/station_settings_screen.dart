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
  int _selectedSettingsTab = 0; // 0 = Location & Scan, 1 = Entry categories, 2 = Shift Timings, 3 = Database & Testing

  late double _radius;
  late bool _checkLocation;
  late bool _allowStaffTotaliserScan;
  late String _defaultLang;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<StationStateProvider>(context, listen: false).settings;
    _radius = settings.radiusMeters;
    _checkLocation = settings.checkLocationBeforeScan;
    _allowStaffTotaliserScan = settings.allowStaffTotaliserCameraScan;
    _defaultLang = settings.defaultLanguage;
  }

  void _saveGeneralSettings(StationStateProvider state) {
    final updated = state.settings.copyWith(
      radiusMeters: _radius,
      checkLocationBeforeScan: _checkLocation,
      allowStaffTotaliserCameraScan: _allowStaffTotaliserScan,
      defaultLanguage: _defaultLang,
    );
    state.updateSettings(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Station settings saved successfully.'),
        backgroundColor: StationColors.successGreen,
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
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tab Body
          if (_selectedSettingsTab == 0) _buildLocationAndScanTab(state),
          if (_selectedSettingsTab == 1) _buildEntryCategoriesTab(state),
          if (_selectedSettingsTab == 2) _buildShiftTimingsTab(state),
          if (_selectedSettingsTab == 3) _buildDatabaseTestingTab(state),
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
              const Text('Station location & perimeter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Configure GPS coordinates and valid scanning radius.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
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
              decoration: const InputDecoration(labelText: 'Category Name (e.g. Toll / Generator)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subCtrl,
              decoration: const InputDecoration(labelText: 'Subtitle / Notes (optional)'),
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
              decoration: const InputDecoration(labelText: 'Category Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subCtrl,
              decoration: const InputDecoration(labelText: 'Subtitle / Notes'),
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

  // --- TAB 3: Database & Testing ---
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
          const Text('Developer & Testing Controls (Cloud Firestore)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          const Text('Manage authoritative collections for "reya-filling-station-chatrai".', style: TextStyle(fontSize: 13, color: StationColors.textMedium)),
          const SizedBox(height: 24),

          // Action 1: Seed to Firestore
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
                      Text('Sync & Seed Authoritative Data to Firestore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: StationColors.textDark)),
                      SizedBox(height: 2),
                      Text('Pushes station doc, Kalyan & Ranjit owners, pumps, nozzles, and settings to Firestore path /stations/chatrai.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                  label: const Text('Seed to Firestore', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      Text('Single-Click Firestore Operational Collection Purge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: StationColors.errorRed)),
                      SizedBox(height: 2),
                      Text('Deletes all test entries, totaliser scans, and shift requests from Firestore so you can test clean states anytime.', style: TextStyle(fontSize: 12, color: StationColors.textMedium)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, size: 16, color: Colors.white),
                  label: const Text('Clear Collections', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            Text('Clear Firestore Collections?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to purge operational records (entries, scan attempts, timing requests) from Firestore?\n\nThis is useful for resetting test runs.',
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
}
