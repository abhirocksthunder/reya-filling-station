import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/pump.dart';
import '../models/shift.dart';
import '../models/shift_timing_request.dart';
import '../models/transaction_entry.dart';
import '../models/receipt_scan.dart';
import '../models/credit_customer.dart';
import '../models/station_settings.dart';
import '../core/formatting/date_formatter.dart';
import '../core/formatting/currency_formatter.dart';
import 'reconciliation_service.dart';

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

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'timestamp': timestamp.toIso8601String(),
    'isWarning': isWarning,
  };

  factory OwnerNotificationItem.fromMap(Map<String, dynamic> map) => OwnerNotificationItem(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    subtitle: map['subtitle'] ?? '',
    timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    isWarning: map['isWarning'] ?? false,
  );
}

class StationStateProvider extends ChangeNotifier {
  static const String _prefActiveUserId = 'rfs_active_user_id';
  static const String _prefUsersList = 'rfs_users_list';
  static const String _prefPumpsList = 'rfs_pumps_list';
  static const String _prefReceiptsList = 'rfs_receipts_list';
  static const String _prefEntriesList = 'rfs_entries_list';
  static const String _prefSettingsJson = 'rfs_settings_json';
  static const String _prefCreditCustomersList = 'rfs_credit_customers_list';
  static const String _prefNotificationsList = 'rfs_notifications_list';

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

  // Active Scan Target Pump
  String? _activeScanPumpId;
  String? get activeScanPumpId => _activeScanPumpId;

  void setActiveScanPumpId(String id) {
    _activeScanPumpId = id;
    notifyListeners();
  }

  // Shifts History
  List<Shift> _allShifts = [];
  List<Shift> get allShifts => _allShifts;

  // Transaction Entries (Strictly dynamic)
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

  // Receipts Inbox
  List<ReceiptScan> _receipts = [];
  List<ReceiptScan> get receipts => _receipts;

  // Credit Customers
  List<CreditCustomer> _creditCustomers = [];
  List<CreditCustomer> get creditCustomers => _creditCustomers;

  // Shift Timing Requests
  List<ShiftTimingRequest> _timingRequests = [];
  List<ShiftTimingRequest> get timingRequests => _timingRequests;

  // Owner Notifications
  List<OwnerNotificationItem> _notifications = [];
  List<OwnerNotificationItem> get notifications => _notifications;

  // Cloud Database handle
  FirebaseFirestore? _firestore;

  StationStateProvider() {
    _initializeDefaultData();
    _loadLocalPersistedState();
    _initFirestore();
  }

  // --- LOCAL PERSISTENCE LAYER ---
  Future<void> _loadLocalPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Restore Users
      final usersJson = prefs.getString(_prefUsersList);
      if (usersJson != null && usersJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(usersJson);
        final list = decoded.map((m) => UserProfile.fromMap(Map<String, dynamic>.from(m))).toList();
        if (list.isNotEmpty) {
          _allUsers = list;
        }
      }

      // 2. Restore Active User Session (survives page refreshes)
      final savedUserId = prefs.getString(_prefActiveUserId);
      if (savedUserId != null && savedUserId.isNotEmpty) {
        final match = _allUsers.where((u) => u.id == savedUserId);
        if (match.isNotEmpty) {
          _currentUser = match.first;
        }
      }

      // 3. Restore Pumps
      final pumpsJson = prefs.getString(_prefPumpsList);
      if (pumpsJson != null && pumpsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(pumpsJson);
        final list = decoded.map((m) => Pump.fromMap(Map<String, dynamic>.from(m))).toList();
        if (list.isNotEmpty) {
          _pumps = list;
        }
      }

      // 4. Restore Receipts
      final receiptsJson = prefs.getString(_prefReceiptsList);
      if (receiptsJson != null && receiptsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(receiptsJson);
        _receipts = decoded.map((m) => ReceiptScan.fromMap(Map<String, dynamic>.from(m))).toList();
      }

      // 5. Restore Entries
      final entriesJson = prefs.getString(_prefEntriesList);
      if (entriesJson != null && entriesJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(entriesJson);
        _entries = decoded.map((m) => TransactionEntry.fromMap(Map<String, dynamic>.from(m))).toList();
      }

      // 6. Restore Settings
      final settingsJson = prefs.getString(_prefSettingsJson);
      if (settingsJson != null && settingsJson.isNotEmpty) {
        _settings = StationSettings.fromMap(Map<String, dynamic>.from(jsonDecode(settingsJson)));
      }

      // 7. Restore Credit Customers
      final creditJson = prefs.getString(_prefCreditCustomersList);
      if (creditJson != null && creditJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(creditJson);
        _creditCustomers = decoded.map((m) => CreditCustomer.fromMap(Map<String, dynamic>.from(m))).toList();
      }

      // 8. Restore Notifications
      final notifsJson = prefs.getString(_prefNotificationsList);
      if (notifsJson != null && notifsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(notifsJson);
        _notifications = decoded.map((m) => OwnerNotificationItem.fromMap(Map<String, dynamic>.from(m))).toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Local persistence loading fallback: $e');
    }
  }

  Future<void> _savePersistedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_allUsers.map((u) => u.toMap()).toList());
      await prefs.setString(_prefUsersList, encoded);
    } catch (_) {}
  }

  Future<void> _savePersistedPumps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_pumps.map((p) => p.toMap()).toList());
      await prefs.setString(_prefPumpsList, encoded);
    } catch (_) {}
  }

  Future<void> _savePersistedReceipts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_receipts.map((r) => r.toMap()).toList());
      await prefs.setString(_prefReceiptsList, encoded);
    } catch (_) {}
  }

  Future<void> _savePersistedEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_entries.map((e) => e.toMap()).toList());
      await prefs.setString(_prefEntriesList, encoded);
    } catch (_) {}
  }

  Future<void> _savePersistedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_settings.toMap());
      await prefs.setString(_prefSettingsJson, encoded);
    } catch (_) {}
  }

  Future<void> _savePersistedCreditCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_creditCustomers.map((c) => c.toMap()).toList());
      await prefs.setString(_prefCreditCustomersList, encoded);
    } catch (_) {}
  }

  Future<void> _savePersistedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_notifications.map((n) => n.toMap()).toList());
      await prefs.setString(_prefNotificationsList, encoded);
    } catch (_) {}
  }

  // --- CLOUD SYNC INITIALIZATION ---
  void _initFirestore() {
    try {
      _firestore = FirebaseFirestore.instance;
      _listenToRemoteSettings();
      _listenToRemoteMembers();
      _listenToRemotePumps();
      _listenToRemoteEntries();
      _listenToRemoteReceipts();
      _listenToRemoteTimingRequests();
      _listenToRemoteCreditCustomers();
      _listenToRemoteNotifications();
    } catch (e) {
      debugPrint('Cloud sync offline fallback active: $e');
    }
  }

  void _listenToRemoteSettings() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('settings').doc('general').snapshots().listen((doc) {
        if (doc.exists && doc.data() != null) {
          _settings = StationSettings.fromMap(doc.data()!);
          _savePersistedSettings();
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
          _savePersistedUsers();
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
          _savePersistedPumps();
          notifyListeners();
        }
      });
    } catch (_) {}
  }

  void _listenToRemoteEntries() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('entries').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final remote = snapshot.docs.map((doc) => TransactionEntry.fromMap(doc.data())).toList();
          final map = <String, TransactionEntry>{};
          for (var e in _entries) {
            map[e.id] = e;
          }
          for (var e in remote) {
            map[e.id] = e;
          }
          final list = map.values.toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _entries = list;
          _savePersistedEntries();
          notifyListeners();
        } else if (_entries.isNotEmpty) {
          _syncLocalEntriesToFirestore();
        }
      }, onError: (e) {
        debugPrint('Remote entries sync error: $e');
      });
    } catch (_) {}
  }

  void _syncLocalEntriesToFirestore() {
    if (_firestore == null || _entries.isEmpty) return;
    for (var e in _entries) {
      _firestore!.collection('stations').doc('chatrai').collection('entries').doc(e.id).set(e.toMap()).catchError((_) {});
    }
  }

  void _listenToRemoteReceipts() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('scanAttempts').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final remote = snapshot.docs.map((doc) => ReceiptScan.fromMap(doc.data())).toList();
          final map = <String, ReceiptScan>{};
          for (var r in _receipts) {
            map[r.id] = r;
          }
          for (var r in remote) {
            map[r.id] = r;
          }
          final list = map.values.toList();
          list.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
          _receipts = list;
          _savePersistedReceipts();
          notifyListeners();
        }
      }, onError: (e) {
        debugPrint('Remote receipts sync error: $e');
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

  void _listenToRemoteCreditCustomers() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('creditCustomers').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final remote = snapshot.docs.map((doc) => CreditCustomer.fromMap(doc.data())).toList();
          final map = <String, CreditCustomer>{};
          for (var c in _creditCustomers) {
            map[c.id] = c;
          }
          for (var c in remote) {
            map[c.id] = c;
          }
          _creditCustomers = map.values.toList();
          _savePersistedCreditCustomers();
          notifyListeners();
        }
      });
    } catch (_) {}
  }

  void _listenToRemoteNotifications() {
    if (_firestore == null) return;
    try {
      _firestore!.collection('stations').doc('chatrai').collection('notifications').snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final remote = snapshot.docs.map((doc) => OwnerNotificationItem.fromMap(doc.data())).toList();
          final map = <String, OwnerNotificationItem>{};
          for (var n in _notifications) {
            map[n.id] = n;
          }
          for (var n in remote) {
            map[n.id] = n;
          }
          final list = map.values.toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _notifications = list;
          _savePersistedNotifications();
          notifyListeners();
        }
      });
    } catch (_) {}
  }

  void _initializeDefaultData() {
    final todayStr = DateFormatter.formatDisplayDate(DateTime.now());

    // 1. Authoritative Owners & Staff
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

    _currentUser = null;

    // 2. Dispensers & Pumps with separate serials & reference receipts
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

    // 3. Operational Shifts
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
        pumpName: 'Pump 2',
        status: ShiftStatus.scheduled,
        timeRange: _settings.shiftTimings['Evening'] ?? '2:00 PM - 10:00 PM',
        openingReadingsMl: const {1: 84520100, 2: 135400200},
        closingReadingsMl: const {1: 84520100, 2: 135400200},
        testVolumesMl: const {1: 5000, 2: 5000},
        cashHandoverPaise: 0,
      ),
    ];

    _entries = [];
    _creditCustomers = [];
    _receipts = [];

    _notifications = [];
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

    // Persist login state to survive browser reload
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefActiveUserId, user.id);
      _savePersistedUsers();
    });

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

    // Clear saved session on logout
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_prefActiveUserId);
      _savePersistedUsers();
    });

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
    _entries.removeWhere((e) => e.id == entry.id);
    _entries.insert(0, entry);
    _savePersistedEntries();
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('entries').doc(entry.id).set(entry.toMap());
      } catch (_) {}
    }

    // Dynamic notification dispatch
    String notifTitle;
    String notifSub;
    switch (entry.category) {
      case EntryCategory.phonePe:
        notifTitle = 'PhonePe Payment: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = '${entry.phonePeNumber != null && entry.phonePeNumber!.isNotEmpty ? "Mobile: ${entry.phonePeNumber} • " : ""}Recorded by ${entry.createdBy}';
        break;
      case EntryCategory.card:
        notifTitle = 'Card Swipe: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = 'Recorded by ${entry.createdBy}';
        break;
      case EntryCategory.cash:
        notifTitle = 'Cash Payment: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = 'Recorded by ${entry.createdBy}';
        break;
      case EntryCategory.toOwner:
        notifTitle = 'Cash Handover: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = 'Handed over to owner by ${entry.createdBy}';
        break;
      case EntryCategory.expense:
        notifTitle = 'Expense: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = '${entry.reference ?? "Expense"} • by ${entry.createdBy}';
        break;
      case EntryCategory.credit:
        notifTitle = 'Credit Sale: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = '${entry.reference ?? "Credit customer"} • by ${entry.createdBy}';
        break;
      default:
        notifTitle = '${entry.category.displayName}: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = 'Recorded by ${entry.createdBy}';
    }
    addNotification(title: notifTitle, subtitle: notifSub);

    notifyListeners();
  }

  void updateTransactionEntry(TransactionEntry updatedEntry) {
    int idx = _entries.indexWhere((e) => e.id == updatedEntry.id);
    if (idx != -1) {
      _entries[idx] = updatedEntry;
      _savePersistedEntries();
      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('entries').doc(updatedEntry.id).set(updatedEntry.toMap());
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  void addNotification({
    required String title,
    required String subtitle,
    bool isWarning = false,
  }) {
    final notif = OwnerNotificationItem(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subtitle: subtitle,
      timestamp: DateTime.now(),
      isWarning: isWarning,
    );
    _notifications.insert(0, notif);
    _savePersistedNotifications();
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('notifications').doc(notif.id).set(notif.toMap()).catchError((_) {});
      } catch (_) {}
    }
    notifyListeners();
  }

  void saveReceiptScan(ReceiptScan inputScan) {
    final isOwner = inputScan.capturedBy.toLowerCase().contains('owner');
    final scan = isOwner && inputScan.reviewStatus != 'approved'
        ? inputScan.copyWith(reviewStatus: 'approved', statusMessage: 'Direct owner totaliser receipt recorded.')
        : inputScan;

    _receipts.removeWhere((r) => r.id == scan.id);
    _receipts.insert(0, scan);
    _savePersistedReceipts();

    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('scanAttempts').doc(scan.id).set(scan.toMap());
      } catch (_) {}
    }

    // Dynamic totaliser update for matching pump
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
      _savePersistedPumps();

      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('pumps').doc(updatedPump.id).set(updatedPump.toMap());
        } catch (_) {}
      }
    }

    // Update active shift closing readings
    int shiftIdx = _allShifts.indexWhere((s) => s.id == activeShift.id);
    if (shiftIdx != -1) {
      Map<int, int> closing = Map.from(_allShifts[shiftIdx].closingReadingsMl);
      scan.nozzleCumVolumeMl.forEach((k, v) => closing[k] = v);
      _allShifts[shiftIdx] = _allShifts[shiftIdx].copyWith(closingReadingsMl: closing);
    }

    addNotification(
      title: 'Receipt Captured: Pump ${scan.fpId}',
      subtitle: 'By ${scan.capturedBy} • ${scan.printedDate} ${scan.printedTime}',
    );

    notifyListeners();
  }

  // --- Pump Baseline Configuration ---
  void setPumpOpeningBaseline(String pumpId, double n1Litres, double n2Litres) {
    int idx = _pumps.indexWhere((p) => p.id == pumpId);
    if (idx != -1) {
      Pump pump = _pumps[idx];
      int n1Ml = (n1Litres * 1000).round();
      int n2Ml = (n2Litres * 1000).round();

      List<Nozzle> updatedNozzles = pump.nozzles.map((n) {
        if (n.nozzleNumber == 1) {
          return n.copyWith(
            previousAcceptedReadingMl: n1Ml,
            currentTotaliserMl: n.currentTotaliserMl < n1Ml ? n1Ml : n.currentTotaliserMl,
          );
        } else if (n.nozzleNumber == 2) {
          return n.copyWith(
            previousAcceptedReadingMl: n2Ml,
            currentTotaliserMl: n.currentTotaliserMl < n2Ml ? n2Ml : n.currentTotaliserMl,
          );
        }
        return n;
      }).toList();

      _pumps[idx] = pump.copyWith(nozzles: updatedNozzles);
      _savePersistedPumps();

      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('pumps').doc(pumpId).set(_pumps[idx].toMap());
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  // --- Owner Base Totaliser Image Upload ---
  void updatePumpBaseTotaliserImage(String pumpId, String imagePath) {
    int idx = _pumps.indexWhere((p) => p.id == pumpId);
    if (idx != -1) {
      _pumps[idx] = _pumps[idx].copyWith(referenceReceiptAsset: imagePath);
      _savePersistedPumps();
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

  // --- Pump Configuration CRUD ---
  void addPump(Pump pump) {
    _pumps.add(pump);
    _savePersistedPumps();
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('pumps').doc(pump.id).set(pump.toMap()).catchError((_) {});
      } catch (_) {}
    }
    addNotification(
      title: 'New Pump Added: ${pump.name}',
      subtitle: 'Serial No: ${pump.serialNumber} with ${pump.nozzles.length} nozzles',
    );
    notifyListeners();
  }

  void updatePump(Pump updatedPump) {
    int idx = _pumps.indexWhere((p) => p.id == updatedPump.id);
    if (idx != -1) {
      _pumps[idx] = updatedPump;
      _savePersistedPumps();
      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('pumps').doc(updatedPump.id).set(updatedPump.toMap()).catchError((_) {});
        } catch (_) {}
      }
      addNotification(
        title: 'Pump Updated: ${updatedPump.name}',
        subtitle: 'Serial No: ${updatedPump.serialNumber}',
      );
      notifyListeners();
    }
  }

  void deletePump(String pumpId) {
    final pump = _pumps.firstWhere((p) => p.id == pumpId, orElse: () => Pump(id: pumpId, name: 'Pump', serialNumber: '', nozzles: const []));
    _pumps.removeWhere((p) => p.id == pumpId);
    _savePersistedPumps();
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('pumps').doc(pumpId).delete().catchError((_) {});
      } catch (_) {}
    }
    addNotification(
      title: 'Pump Removed: ${pump.name}',
      subtitle: 'Dispenser was deleted by owner',
      isWarning: true,
    );
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

  void recordCreditSale({
    required String customerName,
    String subtitle = '',
    required int amountPaise,
    String? reference,
    required String staffName,
  }) {
    final cleanName = customerName.trim();
    final cleanSubtitle = subtitle.trim();

    final entry = TransactionEntry(
      id: 'entry_${DateTime.now().millisecondsSinceEpoch}',
      shiftId: activeShift.id,
      category: EntryCategory.credit,
      direction: EntryDirection.received,
      amountPaise: amountPaise,
      reference: cleanSubtitle.isNotEmpty ? '$cleanName ($cleanSubtitle)' : cleanName,
      createdAt: DateTime.now(),
      createdBy: staffName,
    );
    addTransactionEntry(entry);

    int idx = _creditCustomers.indexWhere(
      (c) => c.name.trim().toLowerCase() == cleanName.toLowerCase(),
    );

    if (idx != -1) {
      final cust = _creditCustomers[idx];
      final updated = cust.copyWith(
        pendingAmountPaise: cust.pendingAmountPaise + amountPaise,
        lastCreditDate: DateTime.now(),
        subtitle: cleanSubtitle.isNotEmpty ? cleanSubtitle : cust.subtitle,
      );
      _creditCustomers[idx] = updated;
      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('creditCustomers').doc(updated.id).set(updated.toMap()).catchError((_) {});
        } catch (_) {}
      }
    } else {
      final newCust = CreditCustomer(
        id: 'cust_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanName,
        subtitle: cleanSubtitle.isNotEmpty ? cleanSubtitle : 'Customer on Credit',
        pendingAmountPaise: amountPaise,
        lastCreditDate: DateTime.now(),
        payments: const [],
      );
      _creditCustomers.insert(0, newCust);
      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('creditCustomers').doc(newCust.id).set(newCust.toMap()).catchError((_) {});
        } catch (_) {}
      }
    }
    _savePersistedCreditCustomers();
    notifyListeners();
  }

  void recordCreditPayment(String customerId, int amountPaise, String mode) {
    int idx = _creditCustomers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      CreditCustomer cust = _creditCustomers[idx];
      int updatedPending = (cust.pendingAmountPaise - amountPaise).clamp(0, double.infinity).toInt();
      final newPayment = CreditPayment(
        id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        amountPaise: amountPaise,
        mode: mode,
      );
      final updatedPayments = List<CreditPayment>.from(cust.payments)..add(newPayment);
      final updated = cust.copyWith(
        pendingAmountPaise: updatedPending,
        payments: updatedPayments,
      );
      _creditCustomers[idx] = updated;
      _savePersistedCreditCustomers();
      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('creditCustomers').doc(updated.id).set(updated.toMap()).catchError((_) {});
        } catch (_) {}
      }
      addNotification(
        title: 'Credit Payment: ${CurrencyFormatter.formatPaise(amountPaise)} by ${cust.name}',
        subtitle: 'Mode: $mode • Remaining: ${CurrencyFormatter.formatPaise(updatedPending)}',
      );
      notifyListeners();
    }
  }

  void approveReceipt(String scanId) {
    int idx = _receipts.indexWhere((r) => r.id == scanId);
    if (idx != -1) {
      final old = _receipts[idx];
      final approved = old.copyWith(
        reviewStatus: 'approved',
        statusMessage: 'Approved by Owner.',
      );
      _receipts[idx] = approved;
      _savePersistedReceipts();

      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('scanAttempts').doc(scanId).update({
            'reviewStatus': 'approved',
            'statusMessage': 'Approved by Owner.',
          }).catchError((_) {});
        } catch (_) {}
      }

      // Update nozzle totalisers with approved readings
      int pumpIdx = _pumps.indexWhere((p) =>
          p.serialNumber == approved.pumpSerialNumber ||
          p.id == 'pump_${approved.fpId}' ||
          p.name.toLowerCase().contains('pump ${approved.fpId}'.toLowerCase()));

      if (pumpIdx != -1) {
        Pump pump = _pumps[pumpIdx];
        List<Nozzle> updatedNozzles = pump.nozzles.map((nozzle) {
          if (approved.nozzleCumVolumeMl.containsKey(nozzle.nozzleNumber)) {
            int newReadingMl = approved.nozzleCumVolumeMl[nozzle.nozzleNumber]!;
            return nozzle.copyWith(
              previousAcceptedReadingMl: nozzle.currentTotaliserMl,
              currentTotaliserMl: newReadingMl,
              previousReadingTimestamp: approved.capturedAt,
            );
          }
          return nozzle;
        }).toList();

        Pump updatedPump = pump.copyWith(nozzles: updatedNozzles);
        _pumps[pumpIdx] = updatedPump;
        _savePersistedPumps();

        if (_firestore != null) {
          try {
            _firestore!.collection('stations').doc('chatrai').collection('pumps').doc(updatedPump.id).set(updatedPump.toMap()).catchError((_) {});
          } catch (_) {}
        }
      }

      addNotification(
        title: 'Receipt Approved: Pump ${approved.fpId}',
        subtitle: 'Readings updated for Pump ${approved.fpId} nozzles by owner',
      );
      notifyListeners();
    }
  }

  void rejectReceipt(String scanId) {
    int idx = _receipts.indexWhere((r) => r.id == scanId);
    if (idx != -1) {
      final old = _receipts[idx];
      final rejected = old.copyWith(
        reviewStatus: 'rejected',
        statusMessage: 'Rejected by Owner. Please rescan.',
      );
      _receipts[idx] = rejected;
      _savePersistedReceipts();

      if (_firestore != null) {
        try {
          _firestore!.collection('stations').doc('chatrai').collection('scanAttempts').doc(scanId).update({
            'reviewStatus': 'rejected',
            'statusMessage': 'Rejected by Owner. Please rescan.',
          }).catchError((_) {});
        } catch (_) {}
      }

      addNotification(
        title: 'Receipt Rejected: Pump ${rejected.fpId}',
        subtitle: 'Rescan requested by owner',
        isWarning: true,
      );
      notifyListeners();
    }
  }

  void updateSettings(StationSettings newSettings) {
    _settings = newSettings;
    _savePersistedSettings();
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('settings').doc('general').set(newSettings.toMap()).catchError((_) {});
        _firestore!.collection('stations').doc('chatrai').set({
          'stationName': newSettings.stationName,
          'latitude': newSettings.latitude,
          'longitude': newSettings.longitude,
          'radiusMeters': newSettings.radiusMeters,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      } catch (_) {}
    }
    addNotification(
      title: 'Station Settings Updated',
      subtitle: '${newSettings.stationName} (${newSettings.latitude.toStringAsFixed(4)}° N, ${newSettings.longitude.toStringAsFixed(4)}° E)',
    );
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
    _savePersistedUsers();
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
      _savePersistedUsers();
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
    _savePersistedUsers();
    if (_firestore != null) {
      try {
        _firestore!.collection('stations').doc('chatrai').collection('members').doc(userId).delete();
      } catch (_) {}
    }
    notifyListeners();
  }

  // --- Authoritative Cloud Sync & Single-Click Purge ---
  Future<String> seedAuthoritativeDataToFirestore() async {
    if (_firestore == null) {
      return 'Central station database is offline. Connect to internet and try again.';
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

      return 'Successfully synchronized station records, owners Kalyan & Ranjit, pumps, and settings!';
    } catch (e) {
      return 'Error synchronizing cloud database: $e';
    }
  }

  Future<String> clearAllFirestoreCollections() async {
    if (_firestore == null) {
      return 'Central station database is offline.';
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
      _savePersistedEntries();
      _savePersistedReceipts();
      notifyListeners();

      return 'Station operational records (entries, scans, timing requests) cleared successfully.';
    } catch (e) {
      return 'Error clearing operational records: $e';
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
