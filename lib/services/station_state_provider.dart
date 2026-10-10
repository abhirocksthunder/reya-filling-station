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

  // Transaction Entries
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
    return _allShifts.isNotEmpty ? _allShifts.first : const Shift(
      id: 'shift_default',
      shiftName: 'Morning',
      businessDate: '10 Oct 2026',
      staffId: 'staff_srikanth',
      staffName: 'Srikanth',
      pumpName: 'Pump 1',
      status: ShiftStatus.inProgress,
      timeRange: '6:00 AM - 2:00 PM',
      openingReadingsMl: {1: 169923720, 2: 274487190},
      closingReadingsMl: {1: 170218850, 2: 275095980},
      testVolumesMl: {1: 5000, 2: 5000},
    );
  }

  // Receipts Inbox (Empty by default for original data display)
  List<ReceiptScan> _receipts = [];
  List<ReceiptScan> get receipts => _receipts;

  // Credit Customers (Khata)
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

    // 2. Pumps & Dispensers
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
            previousReadingTimestamp: DateTime(2026, 10, 9, 21, 50),
          ),
          Nozzle(
            id: 'p1_n2',
            pumpId: 'pump_1',
            nozzleNumber: 2,
            fuelType: 'Diesel',
            ratePaisePerLitre: 10521,
            currentTotaliserMl: 274487190,
            previousAcceptedReadingMl: 273287210,
            previousReadingTimestamp: DateTime(2026, 10, 9, 21, 50),
          ),
        ],
      ),
      const Pump(
        id: 'pump_2',
        name: 'Pump 2',
        serialNumber: '202501001289',
        nozzles: [
          Nozzle(
            id: 'p2_n1',
            pumpId: 'pump_2',
            nozzleNumber: 1,
            fuelType: 'Petrol',
            ratePaisePerLitre: 11752,
            currentTotaliserMl: 84520100,
            previousAcceptedReadingMl: 84120000,
          ),
          Nozzle(
            id: 'p2_n2',
            pumpId: 'pump_2',
            nozzleNumber: 2,
            fuelType: 'Diesel',
            ratePaisePerLitre: 10521,
            currentTotaliserMl: 135400200,
            previousAcceptedReadingMl: 134800000,
          ),
        ],
      ),
    ];

    // 3. Operational Shifts
    _allShifts = [
      const Shift(
        id: 'shift_morning',
        shiftName: 'Morning',
        businessDate: '10 Oct 2026',
        staffId: 'staff_srikanth',
        staffName: 'Srikanth',
        pumpName: 'Pump 1',
        status: ShiftStatus.inProgress,
        timeRange: '6:00 AM - 2:00 PM',
        openingReadingsMl: {1: 169923720, 2: 274487190},
        closingReadingsMl: {1: 170218850, 2: 275095980},
        testVolumesMl: {1: 5000, 2: 5000},
        cashHandoverPaise: 1307400,
      ),
      const Shift(
        id: 'shift_evening',
        shiftName: 'Evening',
        businessDate: '9 Oct 2026',
        staffId: 'staff_kishore',
        staffName: 'Kishore',
        pumpName: 'Pump 1',
        status: ShiftStatus.needsReview,
        timeRange: '2:00 PM - 10:00 PM',
        openingReadingsMl: {1: 168676720, 2: 273287210},
        closingReadingsMl: {1: 168971850, 2: 273901000},
        testVolumesMl: {1: 5000, 2: 5000},
        cashHandoverPaise: 1307400,
      ),
    ];

    // 4. Initial Entries
    _entries = [
      TransactionEntry(
        id: 'entry_1',
        shiftId: 'shift_evening',
        category: EntryCategory.phonePe,
        direction: EntryDirection.received,
        amountPaise: 250000,
        phonePeNumber: '9848012432',
        timeString: '12:15 pm',
        reference: 'Customer UPI',
        createdAt: DateTime(2026, 10, 9, 12, 15),
        createdBy: 'Srikanth',
      ),
      TransactionEntry(
        id: 'entry_2',
        shiftId: 'shift_evening',
        category: EntryCategory.phonePe,
        direction: EntryDirection.received,
        amountPaise: 3056700,
        phonePeNumber: '9440198765',
        timeString: '7:40 pm',
        reference: 'Forecourt QR scans',
        createdAt: DateTime(2026, 10, 9, 19, 40),
        createdBy: 'Srikanth',
      ),
      TransactionEntry(
        id: 'entry_3',
        shiftId: 'shift_evening',
        category: EntryCategory.card,
        direction: EntryDirection.received,
        amountPaise: 453200,
        reference: 'HDFC POS swipe',
        createdAt: DateTime(2026, 10, 9, 18, 20),
        createdBy: 'Srikanth',
      ),
      TransactionEntry(
        id: 'entry_4',
        shiftId: 'shift_evening',
        category: EntryCategory.credit,
        direction: EntryDirection.received,
        amountPaise: 1800000,
        reference: 'Sri Sai Travels (Bus AP16 XX1234)',
        createdAt: DateTime(2026, 10, 9, 16, 0),
        createdBy: 'Srikanth',
      ),
      TransactionEntry(
        id: 'entry_5',
        shiftId: 'shift_evening',
        category: EntryCategory.credit,
        direction: EntryDirection.received,
        amountPaise: 1200000,
        reference: 'Local school bus (N.C)',
        createdAt: DateTime(2026, 10, 9, 17, 30),
        createdBy: 'Srikanth',
      ),
      TransactionEntry(
        id: 'entry_6',
        shiftId: 'shift_evening',
        category: EntryCategory.expense,
        direction: EntryDirection.paidOut,
        amountPaise: 1737300,
        reference: 'Other cash debit',
        createdAt: DateTime(2026, 10, 9, 19, 0),
        createdBy: 'Srikanth',
      ),
      TransactionEntry(
        id: 'entry_7',
        shiftId: 'shift_evening',
        category: EntryCategory.expense,
        direction: EntryDirection.paidOut,
        amountPaise: 10000,
        reference: 'Food / curries',
        createdAt: DateTime(2026, 10, 9, 13, 30),
        createdBy: 'Srikanth',
      ),
      TransactionEntry(
        id: 'entry_8',
        shiftId: 'shift_evening',
        category: EntryCategory.toOwner,
        direction: EntryDirection.paidOut,
        amountPaise: 1307400,
        reference: 'Cash given owner',
        timeString: '10:00 pm',
        createdAt: DateTime(2026, 10, 9, 22, 0),
        createdBy: 'Srikanth',
      ),
    ];

    // 5. Credit Customers
    _creditCustomers = [
      CreditCustomer(
        id: 'cust_srisai',
        name: 'Sri Sai Travels',
        subtitle: 'Bus AP16 XX1234',
        pendingAmountPaise: 1800000,
        lastCreditDate: DateTime(2026, 10, 9),
      ),
      CreditCustomer(
        id: 'cust_schoolbus',
        name: 'Local school bus',
        subtitle: 'School Transport',
        pendingAmountPaise: 1200000,
        lastCreditDate: DateTime(2026, 10, 9),
      ),
    ];

    // 6. Receipts Inbox: Empty by default so original records appear without dummy hardcoded slips
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
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('scanAttempts').doc(scan.id).set(scan.toMap());
      } catch (_) {}
    }
    notifyListeners();
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

  // --- Shift Timings & Timing Requests ---
  void updateShiftTiming(String shiftName, String timeRange) {
    Map<String, String> updated = Map.from(_settings.shiftTimings);
    updated[shiftName] = timeRange;
    updateSettings(_settings.copyWith(shiftTimings: updated));
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

      // Update staff member assignedShift
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
      // 1. Station Document
      await _firestore!.collection('stations').doc('chatrai').set({
        'stationName': 'Reya Filling Station',
        'village': 'Chatrai',
        'district': 'Eluru / Krishna',
        'state': 'Andhra Pradesh',
        'latitude': _settings.latitude,
        'longitude': _settings.longitude,
        'radiusMeters': _settings.radiusMeters,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Settings
      await _firestore!.collection('stations').doc('chatrai').collection('settings').doc('general').set(_settings.toMap());

      // 3. Authoritative Members (Kalyan, Ranjit, Srikanth, Kishore)
      for (var u in _allUsers) {
        await _firestore!.collection('stations').doc('chatrai').collection('members').doc(u.id).set(u.toMap());
      }

      // 4. Dispensers & Pumps
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
      // Clear entries
      final entriesSnap = await _firestore!.collection('stations').doc('chatrai').collection('entries').get();
      for (var doc in entriesSnap.docs) {
        await doc.reference.delete();
      }

      // Clear scanAttempts
      final scansSnap = await _firestore!.collection('stations').doc('chatrai').collection('scanAttempts').get();
      for (var doc in scansSnap.docs) {
        await doc.reference.delete();
      }

      // Clear shiftTimingRequests
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

  ShiftReconciliationReport get sampleShiftReport {
    NozzleCalculationResult petrol = ReconciliationService.calculateNozzle(
      nozzleNumber: 1,
      fuelType: 'Petrol',
      openingReadingMl: 168676720,
      closingReadingMl: 168971850,
      testVolumeMl: 5000,
      ratePaisePerLitre: 11752,
    );

    NozzleCalculationResult diesel = ReconciliationService.calculateNozzle(
      nozzleNumber: 2,
      fuelType: 'Diesel',
      openingReadingMl: 273287210,
      closingReadingMl: 273901000,
      testVolumeMl: 5000,
      ratePaisePerLitre: 10521,
    );

    return ReconciliationService.reconcileShift(
      nozzleResults: [petrol, diesel],
      cashSalesPaise: 3054700,
      phonePeSalesPaise: 3306700,
      cardSalesPaise: 453200,
      creditSalesPaise: 3000000,
      openingCashFloatPaise: 0,
      otherCashDebitsPaise: 1737300,
      foodExpensesPaise: 10000,
      salaryExpensesPaise: 0,
      cashGivenToOwnerPaise: 1307400,
      countedClosingCashPaise: 0,
    );
  }
}
