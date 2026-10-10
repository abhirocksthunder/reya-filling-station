import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/pump.dart';
import '../models/shift.dart';
import '../models/shift_timing_request.dart';
import '../models/transaction_entry.dart';
import '../models/receipt_scan.dart';
import '../models/credit_customer.dart';
import '../models/station_settings.dart';
import '../core/formatting/date_formatter.dart';
import 'reconciliation_service.dart';
import 'ocr_parser_service.dart';
import 'location_service.dart';

class OwnerNotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final bool isWarning;

  const OwnerNotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.isWarning = false,
  });
}

class StationStateProvider extends ChangeNotifier {
  // Current Language: 'te' (Telugu) or 'en' (English)
  String _currentLanguage = 'en';
  String get currentLanguage => _currentLanguage;

  // Active Authenticated User (null if logged out)
  UserProfile? _currentUser;
  UserProfile get currentUser => _currentUser ?? (_allUsers.isNotEmpty ? _allUsers.first : const UserProfile(
    id: 'owner_kalyan',
    name: 'Kalyan',
    email: 'kalyan@rfs.com',
    phoneNumber: '+91 98480 11111',
    role: UserRole.owner,
  ));
  bool get isAuthenticated => _currentUser != null;

  // Station Settings
  StationSettings _settings = const StationSettings();
  StationSettings get settings => _settings;

  // Geofence Simulation
  bool _simulateInsideGeofence = true;
  bool get simulateInsideGeofence => _simulateInsideGeofence;

  // Station Members (Kalyan and Ranjit as authoritative owners)
  List<UserProfile> _allUsers = [];
  List<UserProfile> get allUsers => _allUsers;

  // Pumps & Dispensers
  List<Pump> _pumps = [];
  List<Pump> get pumps => _pumps;

  // Shifts History
  List<Shift> _allShifts = [];
  List<Shift> get allShifts => _allShifts;

  // Transaction Entries (Strictly dynamic - NO dummy entries by default)
  List<TransactionEntry> _entries = [];
  List<TransactionEntry> get entries => _entries;

  // Filtered Entries for Authenticated User (Zero-trust isolation)
  List<TransactionEntry> get userEntries {
    if (_currentUser == null) return [];
    if (_currentUser!.role == UserRole.owner || _currentUser!.role == UserRole.manager) {
      return _entries;
    }
    return _entries.where((e) => e.createdBy == _currentUser!.name || e.shiftId == activeShift.id).toList();
  }

  // Active Shift for Current User
  Shift get activeShift {
    if (_currentUser != null && _currentUser!.assignedShift != null && _allShifts.isNotEmpty) {
      return _allShifts.firstWhere(
        (s) => s.shiftName.toLowerCase() == _currentUser!.assignedShift!.toLowerCase(),
        orElse: () => _allShifts.first,
      );
    }
    final todayStr = DateFormatter.formatDisplayDate(DateTime.now());
    return _allShifts.isNotEmpty ? _allShifts.first : Shift(
      id: 'shift_default',
      shiftName: 'Morning',
      businessDate: todayStr,
      staffId: 'staff_srikanth',
      staffName: 'Srikanth',
      pumpName: 'Pump 1',
      status: ShiftStatus.inProgress,
      timeRange: _settings.shiftTimings['Morning'] ?? '6:00 AM - 2:00 PM',
      openingReadingsMl: const {1: 169923720, 2: 274487190},
      closingReadingsMl: const {1: 169923720, 2: 274487190},
      testVolumesMl: const {1: 5000, 2: 5000},
    );
  }

  // Receipts Inbox (Empty by default for original data display)
  List<ReceiptScan> _receipts = [];
  List<ReceiptScan> get receipts => _receipts;

  // Credit Customers (Khata - Dynamic from real entries)
  List<CreditCustomer> _creditCustomers = [];
  List<CreditCustomer> get creditCustomers => _creditCustomers;

  // Shift Timing Requests
  List<ShiftTimingRequest> _timingRequests = [];
  List<ShiftTimingRequest> get timingRequests => _timingRequests;

  // Owner Notifications
  List<OwnerNotificationItem> _notifications = [];
  List<OwnerNotificationItem> get notifications => _notifications;

  // Cloud Firestore handle
  FirebaseFirestore? _firestore;

  StationStateProvider() {
    _initializeDefaultData();
    _initFirestore();
  }

  void _initFirestore() {
    try {
      _firestore = FirebaseFirestore.instance;
      _listenToRemoteSettings();
      _listenToRemoteMembers();
      _listenToRemotePumps();
      _listenToRemoteEntries();
      _listenToRemoteReceipts();
      _listenToRemoteTimingRequests();
    } catch (e) {
      debugPrint('Firestore offline fallback active: $e');
    }
  }

  void _listenToRemoteSettings() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('settings').doc('general').snapshots().listen((doc) {
        if (doc.exists && doc.data() != null) {
          _settings = StationSettings.fromMap(doc.data()!);
          notifyListeners();
        }
      });
    } catch (_) {}
  }

  void _listenToRemoteMembers() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('members').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          List<UserProfile> remoteUsers = snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            data['id'] = doc.id;
            return UserProfile.fromMap(data);
          }).toList();

          _allUsers = remoteUsers;
          if (_currentUser != null) {
            _currentUser = _allUsers.firstWhere((u) => u.id == _currentUser!.id, orElse: () => _currentUser!);
          }
          notifyListeners();
        }
      });
    } catch (_) {}
  }

  void _listenToRemotePumps() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('pumps').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          _pumps = snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            data['id'] = doc.id;
            return Pump.fromMap(data);
          }).toList();
          notifyListeners();
        }
      });
    } catch (_) {}
  }

  void _listenToRemoteEntries() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('entries').snapshots().listen((snapshot) {
        _entries = snapshot.docs.map((doc) => TransactionEntry.fromMap(doc.data())).toList();
        notifyListeners();
      });
    } catch (_) {}
  }

  void _listenToRemoteReceipts() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('scanAttempts').snapshots().listen((snapshot) {
        _receipts = snapshot.docs.map((doc) => ReceiptScan.fromMap(doc.data())).toList();
        notifyListeners();
      });
    } catch (_) {}
  }

  void _listenToRemoteTimingRequests() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('shiftTimingRequests').snapshots().listen((snapshot) {
        _timingRequests = snapshot.docs.map((doc) => ShiftTimingRequest.fromMap(doc.data())).toList();
        notifyListeners();
      });
    } catch (_) {}
  }

  void _initializeDefaultData() {
    final todayStr = DateFormatter.formatDisplayDate(DateTime.now());

    // 1. Authoritative Owners & Staff (Kalyan & Ranjit, junk removed)
    _allUsers = [
      const UserProfile(
        id: 'owner_kalyan',
        name: 'Kalyan',
        email: 'kalyan@rfs.com',
        phoneNumber: '+91 98480 11111',
        role: UserRole.owner,
        assignedShift: null,
        village: 'Chatrai',
        address: 'Main Road, Chatrai',
        preferredLanguage: 'en',
        active: true,
        isOnline: false,
      ),
      const UserProfile(
        id: 'owner_ranjit',
        name: 'Ranjit',
        email: 'ranjit@rfs.com',
        phoneNumber: '+91 98480 22222',
        role: UserRole.owner,
        assignedShift: null,
        village: 'Chatrai',
        address: 'Bypass Road, Chatrai',
        preferredLanguage: 'en',
        active: true,
        isOnline: false,
      ),
      const UserProfile(
        id: 'staff_srikanth',
        name: 'Srikanth',
        email: 'srikanth@rfs.com',
        phoneNumber: '+91 98492 34567',
        role: UserRole.shiftStaff,
        assignedShift: 'Morning',
        village: 'Chatrai',
        address: 'Gandhi Nagar, Chatrai',
        preferredLanguage: 'te',
        active: true,
        isOnline: false,
      ),
      const UserProfile(
        id: 'staff_kishore',
        name: 'Kishore',
        email: 'kishore@rfs.com',
        phoneNumber: '+91 97013 45678',
        role: UserRole.shiftStaff,
        assignedShift: 'Evening',
        village: 'Chatrai',
        address: 'Station Road, Chatrai',
        preferredLanguage: 'te',
        active: true,
        isOnline: false,
      ),
    ];

    // Mandatory login gate: starts unauthenticated
    _currentUser = null;

    // 2. Dispensers & Pumps
    _pumps = [
      Pump(
        id: 'pump_1',
        name: 'Pump 1',
        serialNumber: '202501001272',
        referenceReceiptAsset: 'assets/images/media_1791616403909.jpg',
        nozzles: [
          Nozzle(
            id: 'p1_n1',
            pumpId: 'pump_1',
            nozzleNumber: 1,
            fuelType: 'Petrol',
            ratePaisePerLitre: 11752,
            currentTotaliserMl: 169923720,
            previousAcceptedReadingMl: 168676720,
            previousReadingTimestamp: DateTime.now().subtract(const Duration(hours: 8)),
          ),
          Nozzle(
            id: 'p1_n2',
            pumpId: 'pump_1',
            nozzleNumber: 2,
            fuelType: 'Diesel',
            ratePaisePerLitre: 10521,
            currentTotaliserMl: 274487190,
            previousAcceptedReadingMl: 273287210,
            previousReadingTimestamp: DateTime.now().subtract(const Duration(hours: 8)),
          ),
        ],
      ),
      Pump(
        id: 'pump_2',
        name: 'Pump 2',
        serialNumber: '202501001289',
        referenceReceiptAsset: 'assets/images/media_1791616403909.jpg',
        nozzles: [
          Nozzle(
            id: 'p2_n1',
            pumpId: 'pump_2',
            nozzleNumber: 1,
            fuelType: 'Petrol',
            ratePaisePerLitre: 11752,
            currentTotaliserMl: 84520100,
            previousAcceptedReadingMl: 84120000,
            previousReadingTimestamp: DateTime.now().subtract(const Duration(hours: 8)),
          ),
          Nozzle(
            id: 'p2_n2',
            pumpId: 'pump_2',
            nozzleNumber: 2,
            fuelType: 'Diesel',
            ratePaisePerLitre: 10521,
            currentTotaliserMl: 135400200,
            previousAcceptedReadingMl: 134800000,
            previousReadingTimestamp: DateTime.now().subtract(const Duration(hours: 8)),
          ),
        ],
      ),
    ];

    // 3. Operational Shifts (Uses dynamic today's date)
    _allShifts = [
      Shift(
        id: 'shift_morning',
        shiftName: 'Morning',
        businessDate: todayStr,
        staffId: 'staff_srikanth',
        staffName: 'Srikanth',
        pumpName: 'Pump 1',
        status: ShiftStatus.inProgress,
        timeRange: _settings.shiftTimings['Morning'] ?? '6:00 AM - 2:00 PM',
        openingReadingsMl: const {1: 169923720, 2: 274487190},
        closingReadingsMl: const {1: 169923720, 2: 274487190},
        testVolumesMl: const {1: 5000, 2: 5000},
        cashHandoverPaise: 0,
      ),
      Shift(
        id: 'shift_evening',
        shiftName: 'Evening',
        businessDate: todayStr,
        staffId: 'staff_kishore',
        staffName: 'Kishore',
        pumpName: 'Pump 1',
        status: ShiftStatus.scheduled,
        timeRange: _settings.shiftTimings['Evening'] ?? '2:00 PM - 10:00 PM',
        openingReadingsMl: const {1: 169923720, 2: 274487190},
        closingReadingsMl: const {1: 169923720, 2: 274487190},
        testVolumesMl: const {1: 5000, 2: 5000},
        cashHandoverPaise: 0,
      ),
    ];

    // 4. Initial Entries: EMPTY by default (No dummy data!)
    _entries = [];

    // 5. Credit Customers: EMPTY by default (No dummy data!)
    _creditCustomers = [];

    // 6. Receipts Inbox: EMPTY by default
    _receipts = [];

    // 7. Notifications
    _notifications = [
      OwnerNotificationItem(
        id: 'notif_1',
        title: 'System active',
        subtitle: 'Reya Filling Station online • Chatrai',
        timestamp: DateTime.now(),
      ),
    ];
  }

  // --- ACTIONS ---

  void setLanguage(String lang) {
    _currentLanguage = lang;
    notifyListeners();
  }

  void switchUser(UserProfile user) {
    final updated = user.copyWith(isOnline: true);
    _currentUser = updated;
    int idx = _allUsers.indexWhere((u) => u.id == user.id);
    if (idx != -1) {
      _allUsers[idx] = updated;
    }
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('members').doc(user.id).update({
          'isOnline': true,
        });
      } catch (_) {}
    }
    notifyListeners();
  }

  void logout() {
    if (_currentUser != null) {
      final user = _currentUser!;
      int idx = _allUsers.indexWhere((u) => u.id == user.id);
      if (idx != -1) {
        _allUsers[idx] = user.copyWith(isOnline: false);
      }
      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('members').doc(user.id).update({
            'isOnline': false,
          });
        } catch (_) {}
      }
    }
    _currentUser = null;
    notifyListeners();
  }

  bool isUserOnline(String userId) {
    if (_currentUser?.id == userId) return true;
    final match = _allUsers.firstWhere(
      (u) => u.id == userId,
      orElse: () => const UserProfile(id: '', name: '', phoneNumber: '', role: UserRole.shiftStaff),
    );
    return match.isOnline;
  }

  void toggleGeofenceSimulation() {
    _simulateInsideGeofence = !_simulateInsideGeofence;
    notifyListeners();
  }

  void addTransactionEntry(TransactionEntry entry) {
    _entries.insert(0, entry);
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('entries').doc(entry.id).set(entry.toMap());
      } catch (_) {}
    }
    notifyListeners();
  }

  void updateTransactionEntry(TransactionEntry updatedEntry) {
    int idx = _entries.indexWhere((e) => e.id == updatedEntry.id);
    if (idx != -1) {
      _entries[idx] = updatedEntry;
      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('entries').doc(updatedEntry.id).set(updatedEntry.toMap());
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  void saveReceiptScan(ReceiptScan scan) {
    _receipts.insert(0, scan);

    // 1. Sync scan to Firestore
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('scanAttempts').doc(scan.id).set(scan.toMap());
      } catch (_) {}
    }

    // 2. DYNAMICALLY UPDATE THE MATCHING PUMP AND NOZZLES (Requirement 4)
    int pumpIdx = _pumps.indexWhere((p) =>
        p.serialNumber == scan.pumpSerialNumber ||
        p.id == 'pump_${scan.fpId}' ||
        p.name.toLowerCase().contains('pump ${scan.fpId}'.toLowerCase()));

    if (pumpIdx != -1) {
      Pump pump = _pumps[pumpIdx];
      List<Nozzle> updatedNozzles = pump.nozzles.map((nozzle) {
        if (scan.nozzleCumVolumeMl.containsKey(nozzle.nozzleNumber)) {
          int newReadingMl = scan.nozzleCumVolumeMl[nozzle.nozzleNumber]!;
          return nozzle.copyWith(
            previousAcceptedReadingMl: nozzle.currentTotaliserMl,
            currentTotaliserMl: newReadingMl,
            previousReadingTimestamp: scan.capturedAt,
          );
        }
        return nozzle;
      }).toList();

      Pump updatedPump = pump.copyWith(nozzles: updatedNozzles);
      _pumps[pumpIdx] = updatedPump;

      // Sync updated pump to Firestore
      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('pumps').doc(updatedPump.id).set(updatedPump.toMap());
        } catch (_) {}
      }
    }

    // 3. Update active shift closing readings
    int shiftIdx = _allShifts.indexWhere((s) => s.id == activeShift.id);
    if (shiftIdx != -1) {
      Map<int, int> closing = Map.from(_allShifts[shiftIdx].closingReadingsMl);
      scan.nozzleCumVolumeMl.forEach((k, v) => closing[k] = v);
      _allShifts[shiftIdx] = _allShifts[shiftIdx].copyWith(closingReadingsMl: closing);
    }

    notifyListeners();
  }

  // --- Owner Base Totaliser Image Upload (Requirement 5) ---
  void updatePumpBaseTotaliserImage(String pumpId, String imagePath) {
    int idx = _pumps.indexWhere((p) => p.id == pumpId);
    if (idx != -1) {
      _pumps[idx] = _pumps[idx].copyWith(referenceReceiptAsset: imagePath);
      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('pumps').doc(pumpId).update({
            'referenceReceiptAsset': imagePath,
          });
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  void submitShiftForReview(int cashHandoverPaise) {
    int idx = _allShifts.indexWhere((s) => s.id == activeShift.id);
    if (idx != -1) {
      _allShifts[idx] = _allShifts[idx].copyWith(
        status: ShiftStatus.needsReview,
        cashHandoverPaise: cashHandoverPaise,
        handoverTime: DateTime.now(),
      );
    }
    notifyListeners();
  }

  void recordCreditPayment(String customerId, int amountPaise, String mode) {
    int idx = _creditCustomers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      CreditCustomer cust = _creditCustomers[idx];
      int updatedPending = (cust.pendingAmountPaise - amountPaise).clamp(0, double.infinity).toInt();
      _creditCustomers[idx] = cust.copyWith(pendingAmountPaise: updatedPending);
      notifyListeners();
    }
  }

  void updateSettings(StationSettings newSettings) {
    _settings = newSettings;
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('settings').doc('general').set(newSettings.toMap());
      } catch (_) {}
    }
    notifyListeners();
  }

  // --- Dynamic Categories CRUD ---
  void addCategory(CategoryItem category) {
    List<CategoryItem> updated = List.from(_settings.categories);
    updated.add(category);
    updateSettings(_settings.copyWith(categories: updated));
  }

  void updateCategory(CategoryItem category) {
    List<CategoryItem> updated = _settings.categories.map((c) => c.id == category.id ? category : c).toList();
    updateSettings(_settings.copyWith(categories: updated));
  }

  void deleteCategory(String categoryId) {
    List<CategoryItem> updated = _settings.categories.where((c) => c.id != categoryId).toList();
    updateSettings(_settings.copyWith(categories: updated));
  }

  // --- Shift Timings & Timing Requests (Maintained by Admin/Owner - Requirement 2) ---
  void updateShiftTiming(String shiftName, String timeRange) {
    Map<String, String> updated = Map.from(_settings.shiftTimings);
    updated[shiftName] = timeRange;
    updateSettings(_settings.copyWith(shiftTimings: updated));

    // Update timeRange in allShifts matching this shiftName
    for (int i = 0; i < _allShifts.length; i++) {
      if (_allShifts[i].shiftName.toLowerCase() == shiftName.toLowerCase()) {
        _allShifts[i] = _allShifts[i].copyWith(timeRange: timeRange);
      }
    }
    notifyListeners();
  }

  Future<void> requestShiftTimingChange({
    required String staffId,
    required String staffName,
    required String requestedShift,
    required String timingRange,
    String reason = '',
  }) async {
    final req = ShiftTimingRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      staffId: staffId,
      staffName: staffName,
      requestedShift: requestedShift,
      timingRange: timingRange,
      reason: reason,
      status: 'pending',
      requestedAt: DateTime.now(),
    );
    _timingRequests.insert(0, req);
    if (_firestore != null) {
      try {
        await _firestore!.collection('stations').doc('chatrai').collection('shiftTimingRequests').doc(req.id).set(req.toMap());
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> approveShiftTiming(String requestId) async {
    int idx = _timingRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final req = _timingRequests[idx].copyWith(status: 'approved');
      _timingRequests[idx] = req;

      int userIdx = _allUsers.indexWhere((u) => u.id == req.staffId);
      if (userIdx != -1) {
        final updatedUser = _allUsers[userIdx].copyWith(assignedShift: req.requestedShift);
        updateUser(updatedUser);
      }

      if (_firestore != null) {
        try {
          await _firestore!.collection('stations').doc('chatrai').collection('shiftTimingRequests').doc(req.id).update({
            'status': 'approved',
          });
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> rejectShiftTiming(String requestId) async {
    int idx = _timingRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final req = _timingRequests[idx].copyWith(status: 'rejected');
      _timingRequests[idx] = req;
      if (_firestore != null) {
        try {
          await _firestore!.collection('stations').doc('chatrai').collection('shiftTimingRequests').doc(req.id).update({
            'status': 'rejected',
          });
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  // --- Users CRUD ---
  void addNewUser(UserProfile newUser) {
    _allUsers.add(newUser);
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('members').doc(newUser.id).set(newUser.toMap());
      } catch (_) {}
    }
    notifyListeners();
  }

  void updateUser(UserProfile updatedUser) {
    int idx = _allUsers.indexWhere((u) => u.id == updatedUser.id);
    if (idx != -1) {
      _allUsers[idx] = updatedUser;
      if (_currentUser?.id == updatedUser.id) {
        _currentUser = updatedUser;
      }
      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('members').doc(updatedUser.id).set(updatedUser.toMap());
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  void deleteUser(String userId) {
    _allUsers.removeWhere((u) => u.id == userId);
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('members').doc(userId).delete();
      } catch (_) {}
    }
    notifyListeners();
  }

  // --- Authoritative Firestore Seeding & Single-Click Purge ---
  Future<String> seedAuthoritativeDataToFirestore() async {
    if (_firestore == null) {
      return 'Firestore is offline. Connect to internet and try again.';
    }

    try {
      await _firestore!.collection('stations').doc('chatrai').set({
        'stationName': 'Reya Filling Station',
        'village': 'Chatrai',
        'district': 'Eluru',
        'state': 'Andhra Pradesh',
        'latitude': _settings.latitude,
        'longitude': _settings.longitude,
        'radiusMeters': _settings.radiusMeters,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _firestore!.collection('stations').doc('chatrai').collection('settings').doc('general').set(_settings.toMap());

      for (var u in _allUsers) {
        await _firestore!.collection('stations').doc('chatrai').collection('members').doc(u.id).set(u.toMap());
      }

      for (var p in _pumps) {
        await _firestore!.collection('stations').doc('chatrai').collection('pumps').doc(p.id).set(p.toMap());
      }

      return 'Successfully seeded station, owners Kalyan & Ranjit, pumps, and settings to Firestore!';
    } catch (e) {
      return 'Error seeding Firestore: $e';
    }
  }

  Future<String> clearAllFirestoreCollections() async {
    if (_firestore == null) {
      return 'Firestore is offline.';
    }

    try {
      final entriesSnap = await _firestore!.collection('stations').doc('chatrai').collection('entries').get();
      for (var doc in entriesSnap.docs) {
        await doc.reference.delete();
      }

      final scansSnap = await _firestore!.collection('stations').doc('chatrai').collection('scanAttempts').get();
      for (var doc in scansSnap.docs) {
        await doc.reference.delete();
      }

      final reqsSnap = await _firestore!.collection('stations').doc('chatrai').collection('shiftTimingRequests').get();
      for (var doc in reqsSnap.docs) {
        await doc.reference.delete();
      }

      _entries = [];
      _receipts = [];
      _timingRequests = [];
      notifyListeners();

      return 'Firestore operational collections (entries, scans, timing requests) cleared successfully.';
    } catch (e) {
      return 'Error clearing collections: $e';
    }
  }

  // Dynamic Shift Reconciliation Report calculated from real entries and pump readings
  ShiftReconciliationReport get sampleShiftReport {
    final pump1 = _pumps.isNotEmpty ? _pumps.first : null;
    final nozzle1 = (pump1 != null && pump1.nozzles.isNotEmpty) ? pump1.nozzles[0] : null;
    final nozzle2 = (pump1 != null && pump1.nozzles.length > 1) ? pump1.nozzles[1] : null;

    NozzleCalculationResult petrol = ReconciliationService.calculateNozzle(
      nozzleNumber: 1,
      fuelType: 'Petrol',
      openingReadingMl: nozzle1?.previousAcceptedReadingMl ?? 168676720,
      closingReadingMl: nozzle1?.currentTotaliserMl ?? 169923720,
      testVolumeMl: 5000,
      ratePaisePerLitre: nozzle1?.ratePaisePerLitre ?? 11752,
    );

    NozzleCalculationResult diesel = ReconciliationService.calculateNozzle(
      nozzleNumber: 2,
      fuelType: 'Diesel',
      openingReadingMl: nozzle2?.previousAcceptedReadingMl ?? 273287210,
      closingReadingMl: nozzle2?.currentTotaliserMl ?? 274487190,
      testVolumeMl: 5000,
      ratePaisePerLitre: nozzle2?.ratePaisePerLitre ?? 10521,
    );

    // Sum from real entries if present, otherwise 0
    int cash = 0;
    int phonePe = 0;
    int card = 0;
    int credit = 0;
    int otherDebits = 0;
    int food = 0;
    int toOwner = 0;

    for (var e in _entries) {
      if (e.direction == EntryDirection.received) {
        switch (e.category) {
          case EntryCategory.cash:
            cash += e.amountPaise;
            break;
          case EntryCategory.phonePe:
            phonePe += e.amountPaise;
            break;
          case EntryCategory.card:
            card += e.amountPaise;
            break;
          case EntryCategory.credit:
            credit += e.amountPaise;
            break;
          default:
            cash += e.amountPaise;
        }
      } else {
        switch (e.category) {
          case EntryCategory.toOwner:
            toOwner += e.amountPaise;
            break;
          case EntryCategory.expense:
            if (e.reference?.toLowerCase().contains('food') == true || e.reference?.toLowerCase().contains('curries') == true) {
              food += e.amountPaise;
            } else {
              otherDebits += e.amountPaise;
            }
            break;
          default:
            otherDebits += e.amountPaise;
        }
      }
    }

    return ReconciliationService.reconcileShift(
      nozzleResults: [petrol, diesel],
      cashSalesPaise: cash,
      phonePeSalesPaise: phonePe,
      cardSalesPaise: card,
      creditSalesPaise: credit,
      openingCashFloatPaise: 0,
      otherCashDebitsPaise: otherDebits,
      foodExpensesPaise: food,
      salaryExpensesPaise: 0,
      cashGivenToOwnerPaise: toOwner,
      countedClosingCashPaise: cash - (toOwner + otherDebits + food),
    );
  }
}
