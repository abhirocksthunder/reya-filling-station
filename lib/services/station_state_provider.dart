import 'dart:async';
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
import '../models/apk_release.dart';
import '../models/cash_handover_record.dart';
import '../core/formatting/date_formatter.dart';
import '../core/formatting/currency_formatter.dart';
import 'location_service.dart';
import 'reconciliation_service.dart';
import 'remote_logging_service.dart';
import 'app_version_service.dart';

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

  factory OwnerNotificationItem.fromMap(Map<String, dynamic> map) =>
      OwnerNotificationItem(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        subtitle: map['subtitle'] ?? '',
        timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
        isWarning: map['isWarning'] ?? false,
      );
}

class PumpDayCalculationResult {
  final Pump pump;
  final String staffName;
  final List<NozzleCalculationResult> nozzleResults;
  final int totalFuelSalesPaise;
  final double totalGrossLitres;
  final double totalTestLitres;
  final double totalNetLitres;
  final double msLitres;
  final double hsdLitres;
  final bool hasReadings;

  const PumpDayCalculationResult({
    required this.pump,
    required this.staffName,
    required this.nozzleResults,
    required this.totalFuelSalesPaise,
    required this.totalGrossLitres,
    required this.totalTestLitres,
    required this.totalNetLitres,
    required this.msLitres,
    required this.hsdLitres,
    required this.hasReadings,
  });
}

class StationDayCalculationResult {
  final DateTime date;
  final List<PumpDayCalculationResult> pumpResults;
  final List<NozzleCalculationResult> allNozzleResults;
  final int totalFuelSalesPaise;
  final double totalGrossLitres;
  final double totalTestLitres;
  final double totalNetLitres;
  final double totalMsLitres;
  final double totalHsdLitres;
  final int recordedSalesPaise;
  final int cashSalesPaise;
  final int phonePeSalesPaise;
  final int cardSalesPaise;
  final int creditSalesPaise;
  final int cashGivenToOwnerPaise;
  final int foodExpensesPaise;
  final int otherExpensesPaise;
  final bool hasData;

  const StationDayCalculationResult({
    required this.date,
    required this.pumpResults,
    required this.allNozzleResults,
    required this.totalFuelSalesPaise,
    required this.totalGrossLitres,
    required this.totalTestLitres,
    required this.totalNetLitres,
    required this.totalMsLitres,
    required this.totalHsdLitres,
    required this.recordedSalesPaise,
    required this.cashSalesPaise,
    required this.phonePeSalesPaise,
    required this.cardSalesPaise,
    required this.creditSalesPaise,
    required this.cashGivenToOwnerPaise,
    required this.foodExpensesPaise,
    required this.otherExpensesPaise,
    required this.hasData,
  });
}

class StationStateProvider extends ChangeNotifier {
  static const String _prefActiveUserId = 'rfs_active_user_id';
  static const String _prefUsersList = 'rfs_users_list_v4';
  static const String _prefPumpsList = 'rfs_pumps_list_v4';
  static const String _prefReceiptsList = 'rfs_receipts_list_v4';
  static const String _prefEntriesList = 'rfs_entries_list_v4';
  static const String _prefSettingsJson = 'rfs_settings_json_v4';
  static const String _prefCreditCustomersList = 'rfs_credit_customers_list_v4';
  static const String _prefNotificationsList = 'rfs_notifications_list_v4';
  static const String _prefApkReleasesList = 'rfs_apk_releases_list_v4';
  static const String _prefShiftsList = 'rfs_shifts_list_v4';
  static const String _prefCashHandoversList = 'rfs_cash_handovers_list_v4';

  static const Set<String> _dummyUserNamesLower = {
    'kishore',
    'krishna',
    'srikanth',
  };

  static const Set<String> _dummyUserIdsLower = {
    'staff_kishore',
    'staff_srikanth',
  };

  static const Set<String> _permanentlyPurgedEntryIds = {'entry_1791680675746'};

  String get currentPlatformVersionLabel =>
      '${AppVersionService.displayVersion} (${kIsWeb ? "Web" : "Android"})';

  bool _isDummyUser(String? id, String? name) {
    final cleanId = (id ?? '').trim().toLowerCase();
    final cleanName = (name ?? '').trim().toLowerCase();
    return _dummyUserIdsLower.contains(cleanId) ||
        _dummyUserNamesLower.contains(cleanName);
  }

  bool _isDeletedOrInvalidEntry(TransactionEntry entry) {
    final cleanId = entry.id.trim();
    if (_permanentlyPurgedEntryIds.contains(cleanId)) return true;
    if (entry.status.trim().toLowerCase() == 'deleted') return true;
    if (_settings.deletedEntryIds.contains(cleanId)) return true;
    if (_isDummyUser(null, entry.createdBy)) return true;
    return false;
  }

  // Current Language: 'te' (Telugu) or 'en' (English)
  String _currentLanguage = 'en';
  String get currentLanguage => _currentLanguage;

  // Active Authenticated User (null if logged out)
  UserProfile? _currentUser;
  UserProfile get currentUser =>
      _currentUser ??
      (_allUsers.isNotEmpty
          ? _allUsers.first
          : const UserProfile(
              id: 'owner_kalyan',
              name: 'Kalyan',
              email: 'kalyan@rfs.com',
              phoneNumber: '+91 98480 11111',
              role: UserRole.owner,
            ));
  bool get isAuthenticated => _currentUser != null;

  /// Returns true when [u] corresponds to the currently logged-in user (Self)
  bool isSelfUser(UserProfile u) {
    if (_currentUser == null) return false;
    if (_currentUser!.id == u.id) return true;
    final currPhone = _currentUser!.phoneNumber.replaceAll(RegExp(r'\D'), '');
    final targetPhone = u.phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (currPhone.isNotEmpty && currPhone == targetPhone) return true;
    final currName = _currentUser!.name.trim().toLowerCase();
    final targetName = u.name.trim().toLowerCase();
    if (currName.isNotEmpty &&
        currName == targetName &&
        _currentUser!.role == u.role) {
      return true;
    }
    return false;
  }

  // Station Settings
  StationSettings _settings = const StationSettings();
  StationSettings get settings => _settings;

  // Geofence Simulation & 1-Minute Live Location Telemetry
  bool _simulateInsideGeofence = true;
  bool get simulateInsideGeofence => _simulateInsideGeofence;
  Timer? _locationTimer;
  ({double lat, double lon, double accuracy})? _lastRealDeviceLocation;
  bool _isFetchingDeviceLocation = false;

  // Station Members (Dynamic from Firestore)
  List<UserProfile> _allUsers = [];
  List<UserProfile> get allUsers => _allUsers;

  /// Users created or edited by a Manager that are awaiting Owner approval
  List<UserProfile> get pendingApprovalUsers =>
      _allUsers.where((u) => u.isPendingApproval || u.hasPendingEdit).toList();

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

  // Shifts History & Selected Review Shift for Deep Linking
  List<Shift> _allShifts = [];
  List<Shift> get allShifts => _allShifts;

  /// Returns only shifts that belong to a configured shift timing AND have an
  /// assigned user who is currently logged in (active shift) or has already
  /// submitted/completed the shift. Unassigned or unstarted scheduled shifts
  /// are hidden in the beginning before staff log in.
  List<Shift> get visibleShifts {
    final validShiftNames = _settings.shiftTimings.keys
        .map((k) => k.trim().toLowerCase())
        .toSet();
    return _allShifts.where((s) {
      final sNameLower = s.shiftName.trim().toLowerCase();
      if (validShiftNames.isNotEmpty && !validShiftNames.contains(sNameLower)) {
        return false;
      }
      if (_isDummyUser(s.staffId, s.staffName)) {
        return false;
      }
      // Always show shifts that have been submitted for review or approved by a real user
      final realUserExists = _allUsers.any(
        (u) =>
            u.id == s.staffId ||
            u.name.trim().toLowerCase() == s.staffName.trim().toLowerCase(),
      );
      if (!realUserExists) return false;

      if (s.status == ShiftStatus.needsReview ||
          s.status == ShiftStatus.approved) {
        return true;
      }

      // If status is scheduled, do not show in the beginning before staff logs in & starts shift
      if (s.status == ShiftStatus.scheduled) {
        return false;
      }

      // For inProgress shifts, ensure the assigned user is actually assigned to this shift
      // and either online (logged in) or has recorded activity for this shift
      final assignedUser = _allUsers
          .where(
            (u) =>
                (u.id == s.staffId ||
                    u.name.trim().toLowerCase() ==
                        s.staffName.trim().toLowerCase()) &&
                u.assignedShift != null &&
                u.assignedShift!.trim().toLowerCase() == sNameLower,
          )
          .firstOrNull;

      if (assignedUser == null) return false;

      final hasShiftActivity =
          s.cashHandoverPaise > 0 ||
          _entries.any(
            (e) =>
                e.shiftId == s.id ||
                e.createdBy.trim().toLowerCase() ==
                    assignedUser.name.trim().toLowerCase(),
          ) ||
          _receipts.any(
            (r) =>
                r.capturedBy.trim().toLowerCase() ==
                assignedUser.name.trim().toLowerCase(),
          );

      return isUserOnline(assignedUser.id) || hasShiftActivity;
    }).toList();
  }

  bool isSameDay(DateTime a, DateTime b) {
    final aIst = DateFormatter.toIST(a);
    final bIst = DateFormatter.toIST(b);
    return aIst.year == bIst.year &&
        aIst.month == bIst.month &&
        aIst.day == bIst.day;
  }

  /// Checks whether a shift belongs to a specific calendar date (by businessDate or handoverTime)
  bool isShiftOnDate(Shift s, DateTime date) {
    final targetDateStr = DateFormatter.formatDisplayDate(
      date,
    ).trim().toLowerCase();
    final shiftDateStr = s.businessDate.trim().toLowerCase();
    if (shiftDateStr.isNotEmpty) {
      return shiftDateStr == targetDateStr;
    }
    if (s.handoverTime != null) {
      return isSameDay(s.handoverTime!, date);
    }
    return isSameDay(DateTime.now(), date);
  }

  /// Returns visible shifts strictly filtered for the selected calendar date
  List<Shift> getVisibleShiftsForDate(DateTime date) {
    return visibleShifts.where((s) => isShiftOnDate(s, date)).toList();
  }

  /// Calculates the Cash Handover to Owner (in paise) for a shift from Money Entries ("Paid out -> To owner"),
  /// falling back to shift.cashHandoverPaise when no matching To Owner entries exist.
  int getShiftHandoverToOwnerPaise(Shift shift, {DateTime? date}) {
    final shiftNameLower = shift.shiftName.trim().toLowerCase();
    final staffNameLower = shift.staffName.trim().toLowerCase();
    final targetDateStr = shift.businessDate.trim().toLowerCase();

    int sumFromEntries = 0;
    bool foundMatchingEntry = false;

    for (final e in _entries) {
      if (e.category != EntryCategory.toOwner ||
          e.direction != EntryDirection.paidOut) {
        continue;
      }
      if (date != null && !isSameDay(e.createdAt, date)) {
        continue;
      }
      final entryDateStr = DateFormatter.formatDisplayDate(
        e.createdAt,
      ).trim().toLowerCase();
      final matchesDate =
          targetDateStr.isEmpty || entryDateStr == targetDateStr;
      final matchesShiftOrStaff =
          e.shiftId == shift.id ||
          e.shiftId.toLowerCase().contains(shiftNameLower) ||
          (staffNameLower.isNotEmpty &&
              e.createdBy.trim().toLowerCase() == staffNameLower);

      if (matchesDate && matchesShiftOrStaff) {
        sumFromEntries += e.amountPaise;
        foundMatchingEntry = true;
      }
    }

    if (foundMatchingEntry) {
      return sumFromEntries;
    }

    // Also check if any To Owner entry was recorded on the same business date when single shift is active
    if (targetDateStr.isNotEmpty) {
      int dateToOwnerSum = 0;
      for (final e in _entries) {
        if (e.category == EntryCategory.toOwner &&
            e.direction == EntryDirection.paidOut &&
            DateFormatter.formatDisplayDate(e.createdAt).trim().toLowerCase() ==
                targetDateStr) {
          dateToOwnerSum += e.amountPaise;
        }
      }
      if (dateToOwnerSum > 0 &&
          visibleShifts
                  .where(
                    (s) => s.businessDate.trim().toLowerCase() == targetDateStr,
                  )
                  .length <=
              1) {
        return dateToOwnerSum;
      }
    }

    return shift.cashHandoverPaise;
  }

  /// Synchronizes shift.cashHandoverPaise with "Paid out -> To owner" money entries
  void _syncShiftHandoverFromEntries() {
    bool changed = false;
    for (int i = 0; i < _allShifts.length; i++) {
      final s = _allShifts[i];
      final shiftNameLower = s.shiftName.trim().toLowerCase();
      final staffNameLower = s.staffName.trim().toLowerCase();
      final targetDateStr = s.businessDate.trim().toLowerCase();

      int sum = 0;
      bool hasEntry = false;
      for (final e in _entries) {
        if (e.category == EntryCategory.toOwner &&
            e.direction == EntryDirection.paidOut) {
          final entryDateStr = DateFormatter.formatDisplayDate(
            e.createdAt,
          ).trim().toLowerCase();
          final matchesDate =
              targetDateStr.isEmpty || entryDateStr == targetDateStr;
          final matchesShift =
              e.shiftId == s.id ||
              e.shiftId.toLowerCase().contains(shiftNameLower) ||
              (staffNameLower.isNotEmpty &&
                  e.createdBy.trim().toLowerCase() == staffNameLower);
          if (matchesDate && matchesShift) {
            sum += e.amountPaise;
            hasEntry = true;
          }
        }
      }

      if (hasEntry && s.cashHandoverPaise != sum) {
        _allShifts[i] = s.copyWith(cashHandoverPaise: sum);
        changed = true;
        if (_firestore != null) {
          try {
            _firestore!
                .collection('stations')
                .doc('chatrai')
                .collection('shifts')
                .doc(_allShifts[i].id)
                .set(_allShifts[i].toMap(), SetOptions(merge: true))
                .catchError((_) {});
          } catch (_) {}
        }
      }
    }
    if (changed) {
      _savePersistedShifts();
    }
  }

  /// Returns true if the given user (or currentUser) currently has an active shift in progress
  bool isUserShiftInProgress([UserProfile? user]) {
    final targetUser = user ?? _currentUser;
    if (targetUser == null) return false;

    final assignedShiftName = targetUser.assignedShift?.trim().toLowerCase();
    for (final s in _allShifts) {
      final matchesUser =
          s.staffId == targetUser.id ||
          s.staffName.trim().toLowerCase() ==
              targetUser.name.trim().toLowerCase() ||
          (assignedShiftName != null &&
              assignedShiftName.isNotEmpty &&
              s.shiftName.trim().toLowerCase() == assignedShiftName);
      if (matchesUser && s.status == ShiftStatus.inProgress) {
        return true;
      }
    }
    return false;
  }

  /// True only when the Owner feature flag is enabled AND the user has an active shift in progress
  bool get isLiveLocationTrackingActive =>
      _settings.enableLiveLocationTracking && isUserShiftInProgress();

  /// Resolves a human-readable location name for any coordinate pair
  String resolveCoordinateLocationName(double lat, double lon) {
    return LocationService.resolveLocationName(
      lat: lat,
      lon: lon,
      stationLat: _settings.latitude,
      stationLon: _settings.longitude,
      stationRadiusMeters: _settings.radiusMeters,
      stationName: _settings.stationName,
    );
  }

  /// Resolves a human-readable location name for a user profile
  String resolveUserLocationName(UserProfile user) {
    if (user.lastLocationName != null &&
        user.lastLocationName!.trim().isNotEmpty) {
      return user.lastLocationName!.trim();
    }
    if (user.lastLatitude != null && user.lastLongitude != null) {
      return resolveCoordinateLocationName(
        user.lastLatitude!,
        user.lastLongitude!,
      );
    }
    return 'Location unavailable';
  }

  String? _selectedReviewShiftId;
  String? get selectedReviewShiftId => _selectedReviewShiftId;

  void selectShiftForReview(String? shiftId) {
    _selectedReviewShiftId = shiftId;
    notifyListeners();
  }

  // Transaction Entries (Strictly dynamic)
  List<TransactionEntry> _entries = [];
  List<TransactionEntry> get entries => _entries;

  // Filtered Entries for Authenticated User (Zero-trust isolation)
  List<TransactionEntry> get userEntries {
    if (_currentUser == null) return [];
    if (_currentUser!.hasOwnerPrivileges ||
        _currentUser!.role == UserRole.manager) {
      return _entries;
    }
    return _entries
        .where(
          (e) =>
              e.createdBy == _currentUser!.name || e.shiftId == activeShift.id,
        )
        .toList();
  }

  Map<int, int> _currentPumpReadingsMap() {
    if (_pumps.isNotEmpty && _pumps.first.nozzles.isNotEmpty) {
      return {
        for (final n in _pumps.first.nozzles)
          n.nozzleNumber: n.currentTotaliserMl,
      };
    }
    return const {1: 0, 2: 0};
  }

  // Active Shift for Current User
  Shift get activeShift {
    if (_currentUser != null &&
        _currentUser!.assignedShift != null &&
        _allShifts.isNotEmpty) {
      final matched = _allShifts.where(
        (s) =>
            s.shiftName.toLowerCase() ==
            _currentUser!.assignedShift!.toLowerCase(),
      );
      if (matched.isNotEmpty) return matched.first;
    }
    if (_currentUser != null && _allShifts.isNotEmpty) {
      final matchedByStaff = _allShifts.where(
        (s) => s.staffId == _currentUser!.id,
      );
      if (matchedByStaff.isNotEmpty) return matchedByStaff.first;
    }
    final todayStr = DateFormatter.formatDisplayDate(DateTime.now());
    final shiftName =
        _currentUser?.assignedShift ??
        (_settings.shiftTimings.keys.isNotEmpty
            ? _settings.shiftTimings.keys.first
            : 'Morning');
    final readings = _currentPumpReadingsMap();
    return _allShifts.isNotEmpty
        ? _allShifts.first
        : Shift(
            id: 'shift_${shiftName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
            shiftName: shiftName,
            businessDate: todayStr,
            staffId: _currentUser?.id ?? currentUser.id,
            staffName: _currentUser?.name ?? currentUser.name,
            pumpName: _pumps.isNotEmpty ? _pumps.first.name : 'Pump 1',
            status: _currentUser?.assignedShift != null
                ? ShiftStatus.inProgress
                : ShiftStatus.scheduled,
            timeRange: _settings.shiftTimings[shiftName] ?? '9:00 AM - 9:00 PM',
            openingReadingsMl: readings,
            closingReadingsMl: readings,
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

  // APK Releases History (from Firestore & Local Persistence)
  List<ApkReleaseItem> _apkReleases = [];
  List<ApkReleaseItem> get apkReleases => _apkReleases
      .where((r) => r.buildNumber >= _settings.latestBuildNumber).toList();

  // Cash Handover Workflow Records (Staff -> Manager -> Owner/Admin)
  final Set<String> _purgedHandoverIds = {};
  static const _prefPurgedHandoverIds = 'rfs_purged_handover_ids_v4';
  List<CashHandoverRecord> _cashHandovers = [];
  List<CashHandoverRecord> get cashHandovers => _cashHandovers;

  // Cloud Database handle & authoritative snapshot guards
  FirebaseFirestore? _firestore;
  bool _remoteSettingsLoaded = false;
  bool _remoteUsersLoaded = false;
  bool _remotePumpsLoaded = false;
  bool _remoteReceiptsLoaded = false;
  bool _remoteEntriesLoaded = false;
  bool _remoteCreditLoaded = false;
  bool _remoteNotificationsLoaded = false;
  bool _remoteApkReleasesLoaded = false;
  bool _remoteShiftsLoaded = false;
  bool _remoteCashHandoversLoaded = false;

  StationStateProvider() {
    _initializeDefaultData();
    _loadLocalPersistedState();
    _initFirestore();
  }

  // --- LOCAL PERSISTENCE LAYER ---
  Future<void> _loadLocalPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Purge legacy v1/v2/v3 keys so stale dummy data or deleted entries never resurrect
      const legacyKeys = [
        'rfs_users_list',
        'rfs_pumps_list',
        'rfs_receipts_list',
        'rfs_entries_list',
        'rfs_settings_json',
        'rfs_credit_customers_list',
        'rfs_notifications_list',
        'rfs_apk_releases_list',
        'rfs_shifts_list',
        'rfs_users_list_v3',
        'rfs_pumps_list_v3',
        'rfs_receipts_list_v3',
        'rfs_entries_list_v3',
        'rfs_settings_json_v3',
        'rfs_credit_customers_list_v3',
        'rfs_notifications_list_v3',
        'rfs_apk_releases_list_v3',
        'rfs_shifts_list_v3',
      ];
      for (final key in legacyKeys) {
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
        }
      }

      // 1. Restore Settings first (contains deletedEntryIds & shiftTimings)
      if (!_remoteSettingsLoaded) {
        final settingsJson = prefs.getString(_prefSettingsJson);
        if (settingsJson != null && settingsJson.isNotEmpty) {
          _settings = StationSettings.fromMap(
            Map<String, dynamic>.from(jsonDecode(settingsJson)),
          );
        }
      }

      // 2. Restore Users (excluding any removed dummy users)
      if (!_remoteUsersLoaded) {
        final usersJson = prefs.getString(_prefUsersList);
        if (usersJson != null && usersJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(usersJson);
          final list = decoded
              .map((m) => UserProfile.fromMap(Map<String, dynamic>.from(m)))
              .where((u) => !_isDummyUser(u.id, u.name))
              .toList();
          if (list.isNotEmpty) {
            _allUsers = list;
          }
        }
      }

      // 3. Restore Active User Session (survives page refreshes)
      final savedUserId = prefs.getString(_prefActiveUserId);
      if (savedUserId != null &&
          savedUserId.isNotEmpty &&
          !_isDummyUser(savedUserId, null)) {
        final match = _allUsers.where(
          (u) => u.id == savedUserId && !u.isPendingApproval,
        );
        if (match.isNotEmpty) {
          final now = DateTime.now();
          if (_firestore == null) {
            final loc = getCurrentLiveLocationSnapshot();
            _currentUser = match.first.copyWith(
              isOnline: true,
              appVersion: currentPlatformVersionLabel,
              lastSeenAt: now,
              lastLatitude: loc.lat,
              lastLongitude: loc.lon,
              lastDistanceMeters: loc.distanceMeters,
              lastAccuracyMeters: loc.accuracy,
              isAtStation: loc.isAtStation,
              locationUpdatedAt: now,
            );
          } else {
            final bool hasLegacySim =
                LocationService.isLegacySimulatedCoordinate(
                  lat: match.first.lastLatitude,
                  lon: match.first.lastLongitude,
                  accuracy: match.first.lastAccuracyMeters,
                );
            _currentUser = match.first.copyWith(
              isOnline: true,
              appVersion: currentPlatformVersionLabel,
              lastSeenAt: now,
              clearLocation: hasLegacySim,
            );
            requestAndSyncRealDeviceLocation();
          }
          final idx = _allUsers.indexWhere((u) => u.id == savedUserId);
          if (idx != -1) _allUsers[idx] = _currentUser!;
          _startMinuteLocationTracker();
        }
      }

      // 4. Restore Pumps
      if (!_remotePumpsLoaded) {
        final pumpsJson = prefs.getString(_prefPumpsList);
        if (pumpsJson != null && pumpsJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(pumpsJson);
          final list = decoded
              .map((m) => Pump.fromMap(Map<String, dynamic>.from(m)))
              .toList();
          if (list.isNotEmpty) {
            _pumps = list;
          }
        }
      }

      // 5. Restore Receipts
      if (!_remoteReceiptsLoaded) {
        final receiptsJson = prefs.getString(_prefReceiptsList);
        if (receiptsJson != null && receiptsJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(receiptsJson);
          _receipts = decoded
              .map((m) => ReceiptScan.fromMap(Map<String, dynamic>.from(m)))
              .where((r) => !_isDummyUser(null, r.capturedBy))
              .toList();
        }
      }

      // 6. Restore Entries (only if Firestore hasn't already delivered authoritative snapshot)
      if (!_remoteEntriesLoaded) {
        final entriesJson = prefs.getString(_prefEntriesList);
        if (entriesJson != null && entriesJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(entriesJson);
          _entries = decoded
              .map(
                (m) => TransactionEntry.fromMap(Map<String, dynamic>.from(m)),
              )
              .where((e) => !_isDeletedOrInvalidEntry(e))
              .toList();
        }
      }

      // 7. Restore Credit Customers
      if (!_remoteCreditLoaded) {
        final creditJson = prefs.getString(_prefCreditCustomersList);
        if (creditJson != null && creditJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(creditJson);
          _creditCustomers = decoded
              .map((m) => CreditCustomer.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
      }

      // 8. Restore Notifications
      if (!_remoteNotificationsLoaded) {
        final notifsJson = prefs.getString(_prefNotificationsList);
        if (notifsJson != null && notifsJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(notifsJson);
          _notifications = decoded
              .map(
                (m) =>
                    OwnerNotificationItem.fromMap(Map<String, dynamic>.from(m)),
              )
              .toList();
        }
      }

      // 9. Restore APK Releases
      if (!_remoteApkReleasesLoaded) {
        final apkJson = prefs.getString(_prefApkReleasesList);
        if (apkJson != null && apkJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(apkJson);
          _apkReleases = decoded
              .map((m) => ApkReleaseItem.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
      }

      // 10. Restore Shifts
      if (!_remoteShiftsLoaded) {
        final shiftsJson = prefs.getString(_prefShiftsList);
        if (shiftsJson != null && shiftsJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(shiftsJson);
          final list = decoded
              .map((m) => Shift.fromMap(Map<String, dynamic>.from(m)))
              .where((s) => !_isDummyUser(s.staffId, s.staffName))
              .toList();
          _allShifts = list;
        }
      }

      // Local tombstones survive failed cloud deletes and stale cached snapshots.
      _purgedHandoverIds.addAll(prefs.getStringList(_prefPurgedHandoverIds) ?? []);
      _cashHandovers.removeWhere((h) => _purgedHandoverIds.contains(h.id));

      // 11. Restore Cash Handovers
      if (!_remoteCashHandoversLoaded) {
        final handoversJson = prefs.getString(_prefCashHandoversList);
        if (handoversJson != null && handoversJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(handoversJson);
          _cashHandovers = decoded
              .map(
                (m) => CashHandoverRecord.fromMap(Map<String, dynamic>.from(m)),
              )
              .where((h) => !_purgedHandoverIds.contains(h.id))
              .toList();
        }
      }

      _syncShiftsWithTimings();
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
      final encoded = jsonEncode(
        _creditCustomers.map((c) => c.toMap()).toList(),
      );
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

  Future<void> _savePersistedApkReleases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_apkReleases.map((r) => r.toMap()).toList());
      await prefs.setString(_prefApkReleasesList, encoded);
    } catch (_) {}
  }

  Future<void> _savePersistedShifts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_allShifts.map((s) => s.toMap()).toList());
      await prefs.setString(_prefShiftsList, encoded);
    } catch (_) {}
  }

  Future<void> _savePersistedCashHandovers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_cashHandovers.map((h) => h.toMap()).toList());
      await prefs.setString(_prefCashHandoversList, encoded);
    } catch (_) {}
  }

  // --- CLOUD SYNC INITIALIZATION ---
  void _initFirestore() {
    try {
      _firestore = FirebaseFirestore.instance;
      _listenToRemoteSettings();
      _listenToRemoteMembers();
      _listenToRemotePumps();
      _listenToRemoteShifts();
      _listenToRemoteEntries();
      _listenToRemoteReceipts();
      _listenToRemoteTimingRequests();
      _listenToRemoteCreditCustomers();
      _listenToRemoteNotifications();
      _listenToRemoteApkReleases();
      _listenToRemoteCashHandovers();
    } catch (e) {
      debugPrint('Cloud sync offline fallback active: $e');
    }
  }

  void _listenToRemoteSettings() {
    if (_firestore == null) return;
    try {
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('settings')
          .doc('general')
          .snapshots()
          .listen((doc) {
            if (doc.exists && doc.data() != null) {
              _remoteSettingsLoaded = true;
              _settings = StationSettings.fromMap(doc.data()!);
              _entries.removeWhere((e) => _isDeletedOrInvalidEntry(e));
              _savePersistedSettings();
              _savePersistedEntries();
              _syncShiftsWithTimings();
              notifyListeners();
            }
          });
    } catch (_) {}
  }

  void _listenToRemoteMembers() {
    if (_firestore == null) return;
    try {
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('members')
          .snapshots()
          .listen((snapshot) {
            if (_purgingOperationalData) return;
            if (snapshot.docs.isNotEmpty) {
              _remoteUsersLoaded = true;
              final List<UserProfile> remoteUsers = [];
              for (final doc in snapshot.docs) {
                final Map<String, dynamic> data = doc.data();
                data['id'] = doc.id;
                final user = UserProfile.fromMap(data);
                if (_isDummyUser(user.id, user.name)) {
                  // Automatically purge any leftover dummy user from Firestore
                  doc.reference.delete().catchError((_) {});
                  continue;
                }
                remoteUsers.add(user);
              }

              if (remoteUsers.isNotEmpty) {
                _allUsers = remoteUsers;
              }
              if (_currentUser != null) {
                final idx = _allUsers.indexWhere(
                  (u) => u.id == _currentUser!.id,
                );
                if (idx != -1) {
                  final existing = _allUsers[idx];
                  final currentVer = currentPlatformVersionLabel;
                  if (existing.appVersion != currentVer || !existing.isOnline) {
                    final now = DateTime.now();
                    final updated = existing.copyWith(
                      isOnline: true,
                      appVersion: currentVer,
                      lastSeenAt: now,
                    );
                    _allUsers[idx] = updated;
                    _currentUser = updated;
                    _firestore!
                        .collection('stations')
                        .doc('chatrai')
                        .collection('members')
                        .doc(updated.id)
                        .update({
                          'isOnline': true,
                          'appVersion': currentVer,
                          'lastSeenAt': now.toIso8601String(),
                        })
                        .catchError((_) {});
                  } else {
                    _currentUser = existing;
                  }
                }
              }
              _savePersistedUsers();
              _syncShiftsWithTimings();
              notifyListeners();
            }
          });
    } catch (_) {}
  }

  void _listenToRemotePumps() {
    if (_firestore == null) return;
    try {
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('pumps')
          .snapshots()
          .listen((snapshot) {
            if (_purgingOperationalData) return;
            if (snapshot.docs.isNotEmpty) {
              _remotePumpsLoaded = true;
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
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('entries')
          .snapshots()
          .listen(
            (snapshot) {
              if (_purgingOperationalData) return;
              _remoteEntriesLoaded = true;
              final List<TransactionEntry> remote = [];
              for (final doc in snapshot.docs) {
                final entry = TransactionEntry.fromMap(doc.data());
                if (_isDeletedOrInvalidEntry(entry)) {
                  // Automatically purge deleted tombstone entries, dummy user entries, or deleted shift entries
                  doc.reference.delete().catchError((_) {});
                  continue;
                }
                remote.add(entry);
              }
              remote.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              _entries = remote;
              _syncShiftHandoverFromEntries();
              _savePersistedEntries();
              notifyListeners();
            },
            onError: (e) {
              debugPrint('Remote entries sync error: $e');
            },
          );
    } catch (_) {}
  }

  void _listenToRemoteReceipts() {
    if (_firestore == null) return;
    try {
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('scanAttempts')
          .snapshots()
          .listen(
            (snapshot) {
              if (_purgingOperationalData) return;
              _remoteReceiptsLoaded = true;
              final List<ReceiptScan> remote = [];
              for (final doc in snapshot.docs) {
                final scan = ReceiptScan.fromMap(doc.data());
                if (_isDummyUser(null, scan.capturedBy)) {
                  doc.reference.delete().catchError((_) {});
                  continue;
                }
                remote.add(scan);
              }
              remote.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
              _receipts = remote;
              _savePersistedReceipts();
              notifyListeners();
            },
            onError: (e) {
              debugPrint('Remote receipts sync error: $e');
            },
          );
    } catch (_) {}
  }

  void _listenToRemoteTimingRequests() {
    if (_firestore == null) return;
    try {
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('shiftTimingRequests')
          .snapshots()
          .listen((snapshot) {
            if (_purgingOperationalData) return;
            _timingRequests = snapshot.docs
                .map((doc) => ShiftTimingRequest.fromMap(doc.data()))
                .toList();
            notifyListeners();
          });
    } catch (_) {}
  }

  void _listenToRemoteCreditCustomers() {
    if (_firestore == null) return;
    try {
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('creditCustomers')
          .snapshots()
          .listen((snapshot) {
            if (_purgingOperationalData) return;
            _remoteCreditLoaded = true;
            final remote = snapshot.docs
                .map((doc) => CreditCustomer.fromMap(doc.data()))
                .toList();
            _creditCustomers = remote;
            _savePersistedCreditCustomers();
            notifyListeners();
          });
    } catch (_) {}
  }

  void _listenToRemoteNotifications() {
    if (_firestore == null) return;
    try {
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('notifications')
          .snapshots()
          .listen((snapshot) {
            if (_purgingOperationalData) return;
            _remoteNotificationsLoaded = true;
            final remote = snapshot.docs
                .map((doc) => OwnerNotificationItem.fromMap(doc.data()))
                .toList();
            remote.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            _notifications = remote;
            _savePersistedNotifications();
            notifyListeners();
          });
    } catch (_) {}
  }

  void _listenToRemoteShifts() {
    if (_firestore == null) return;
    try {
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('shifts')
          .snapshots()
          .listen((snapshot) {
            if (_purgingOperationalData) return;
            _remoteShiftsLoaded = true;
            final validShiftNames = _settings.shiftTimings.keys
                .map((k) => k.trim().toLowerCase())
                .toSet();
            final filtered = <Shift>[];
            for (var doc in snapshot.docs) {
              final s = Shift.fromMap(doc.data());
              final isTimingValid =
                  validShiftNames.isEmpty ||
                  validShiftNames.contains(s.shiftName.trim().toLowerCase());
              final isDummy = _isDummyUser(s.staffId, s.staffName);
              if (isTimingValid && !isDummy) {
                filtered.add(s);
              } else {
                // Prune orphaned or dummy shift document from Firestore
                doc.reference.delete().catchError((_) {});
              }
            }
            _allShifts = filtered;
            _syncShiftsWithTimings();
            _savePersistedShifts();
            notifyListeners();
          });
    } catch (_) {}
  }

  void _listenToRemoteApkReleases() {
    if (_firestore == null) return;
    try {
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('apkReleases')
          .snapshots()
          .listen((snapshot) {
            if (_purgingOperationalData) return;
            _remoteApkReleasesLoaded = true;
            final remote = snapshot.docs
                .map((doc) => ApkReleaseItem.fromMap(doc.data()))
                .toList();
            remote.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
            _apkReleases = remote;
            _savePersistedApkReleases();

            if (_apkReleases.isNotEmpty) {
              final newest = _apkReleases.first;
              if (newest.buildNumber > _settings.latestBuildNumber ||
                  (newest.buildNumber == _settings.latestBuildNumber &&
                      newest.version != _settings.latestVersion)) {
                _settings = _settings.copyWith(
                  latestVersion: newest.version,
                  latestBuildNumber: newest.buildNumber,
                  updateUrl: newest.downloadUrl,
                  releaseNotes: newest.releaseNotes.isNotEmpty
                      ? newest.releaseNotes
                      : _settings.releaseNotes,
                );
                _savePersistedSettings();
              }
            }
            notifyListeners();
          });
    } catch (_) {}
  }

  void _listenToRemoteCashHandovers() {
    if (_firestore == null) return;
    try {
      _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('cashHandovers')
          .snapshots()
          .listen((snapshot) {
            if (_purgingOperationalData) return;
            _remoteCashHandoversLoaded = true;
            final remote = snapshot.docs
                .map((doc) => CashHandoverRecord.fromMap(doc.data()))
                .where((h) => !_purgedHandoverIds.contains(h.id))
                .toList();
            remote.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            _cashHandovers = remote;
            _savePersistedCashHandovers();
            notifyListeners();
          });
    } catch (_) {}
  }

  void _initializeDefaultData() {
    // 1. Authoritative Station Members (matches live Firestore members; zero dummy users)
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
        id: 'user_1791651818556',
        name: 'Abhilash',
        email: 'abhi@rfs.com',
        phoneNumber: '9492757943',
        role: UserRole.owner,
        assignedShift: null,
        village: 'Chatrai',
        address: 'Chatrai, Andhra Pradesh',
        preferredLanguage: 'te',
        active: true,
        isOnline: false,
      ),
      const UserProfile(
        id: 'user_1791642830525',
        name: 'Srinivas',
        email: 'srinivas@rfs.com',
        phoneNumber: '9533677647',
        role: UserRole.shiftStaff,
        assignedShift: 'Morning',
        village: 'Chatrai',
        address: 'Chatrai, Andhra Pradesh',
        preferredLanguage: 'te',
        active: true,
        isOnline: false,
      ),
    ];

    _currentUser = null;

    // 2. Dispensers & Pumps (0.0 L sold baseline until actual receipts are uploaded)
    _pumps = [
      const Pump(
        id: 'pump_1',
        name: 'Pump 1',
        serialNumber: '202501001272',
        referenceReceiptAsset: 'assets/images/media_1791634198035.png',
        nozzles: [
          Nozzle(
            id: 'p1_n1',
            pumpId: 'pump_1',
            nozzleNumber: 1,
            fuelType: 'Petrol',
            ratePaisePerLitre: 11752,
            currentTotaliserMl: 168676720,
            previousAcceptedReadingMl: 168676720,
          ),
          Nozzle(
            id: 'p1_n2',
            pumpId: 'pump_1',
            nozzleNumber: 2,
            fuelType: 'Diesel',
            ratePaisePerLitre: 10521,
            currentTotaliserMl: 273287210,
            previousAcceptedReadingMl: 273287210,
          ),
        ],
      ),
      const Pump(
        id: 'pump_2',
        name: 'Pump 2',
        serialNumber: '202501001289',
        referenceReceiptAsset: 'assets/images/media_1791634198035.png',
        nozzles: [
          Nozzle(
            id: 'p2_n1',
            pumpId: 'pump_2',
            nozzleNumber: 1,
            fuelType: 'Petrol',
            ratePaisePerLitre: 11752,
            currentTotaliserMl: 83398950,
            previousAcceptedReadingMl: 83398950,
          ),
          Nozzle(
            id: 'p2_n2',
            pumpId: 'pump_2',
            nozzleNumber: 2,
            fuelType: 'Diesel',
            ratePaisePerLitre: 10521,
            currentTotaliserMl: 121958960,
            previousAcceptedReadingMl: 121958960,
          ),
        ],
      ),
    ];

    // 3. Operational Shifts: strictly dynamic (empty until assigned staff log in)
    _allShifts = [];
    _receipts = [];
    _entries = [];
    _creditCustomers = [];
    _notifications = [];
  }

  // --- ACTIONS ---

  void setLanguage(String lang) {
    _currentLanguage = lang;
    notifyListeners();
  }

  void _activateShiftForLoggedInUser(UserProfile user) {
    final shiftName = user.assignedShift?.trim();
    if (shiftName == null || shiftName.isEmpty) return;

    // Only activate if the shift timing exists in settings
    final matchingTimingKey = _settings.shiftTimings.keys
        .where((k) => k.trim().toLowerCase() == shiftName.toLowerCase())
        .firstOrNull;
    if (matchingTimingKey == null) return;

    final timeRange =
        _settings.shiftTimings[matchingTimingKey] ?? '9:00 AM - 9:00 PM';
    final shiftId =
        'shift_${matchingTimingKey.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
    final todayStr = DateFormatter.formatDisplayDate(DateTime.now());
    final readings = _currentPumpReadingsMap();

    final existingIdx = _allShifts.indexWhere(
      (s) =>
          s.id == shiftId ||
          s.shiftName.trim().toLowerCase() ==
              matchingTimingKey.trim().toLowerCase(),
    );

    Shift activeShiftObj;
    if (existingIdx != -1) {
      final current = _allShifts[existingIdx];
      activeShiftObj = current.copyWith(
        staffId: user.id,
        staffName: user.name,
        timeRange: timeRange,
        status: current.status == ShiftStatus.scheduled
            ? ShiftStatus.inProgress
            : current.status,
      );
      _allShifts[existingIdx] = activeShiftObj;
    } else {
      activeShiftObj = Shift(
        id: shiftId,
        shiftName: matchingTimingKey.trim(),
        businessDate: todayStr,
        staffId: user.id,
        staffName: user.name,
        pumpName: _pumps.isNotEmpty ? _pumps.first.name : 'Pump 1',
        status: ShiftStatus.inProgress,
        timeRange: timeRange,
        openingReadingsMl: readings,
        closingReadingsMl: readings,
        testVolumesMl: const {1: 5000, 2: 5000},
        cashHandoverPaise: 0,
      );
      _allShifts.add(activeShiftObj);
    }

    _savePersistedShifts();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('shifts')
            .doc(activeShiftObj.id)
            .set(activeShiftObj.toMap())
            .catchError((_) {});
      } catch (_) {}
    }
  }

  /// Computes the active user's live GPS coordinates and geofence distance from station center
  ({
    double lat,
    double lon,
    double accuracy,
    double distanceMeters,
    bool isAtStation,
  })
  getCurrentLiveLocationSnapshot() {
    final double baseLat = _settings.latitude;
    final double baseLon = _settings.longitude;

    if (_lastRealDeviceLocation != null) {
      final fix = _lastRealDeviceLocation!;
      final dist = LocationService.calculateDistanceMeters(
        lat1: fix.lat,
        lon1: fix.lon,
        lat2: baseLat,
        lon2: baseLon,
      );
      final inside = (dist + fix.accuracy) <= _settings.radiusMeters;
      return (
        lat: fix.lat,
        lon: fix.lon,
        accuracy: fix.accuracy,
        distanceMeters: dist,
        isAtStation: inside,
      );
    }

    if (_currentUser?.lastLatitude != null &&
        _currentUser?.lastLongitude != null &&
        !LocationService.isLegacySimulatedCoordinate(
          lat: _currentUser!.lastLatitude,
          lon: _currentUser!.lastLongitude,
          accuracy: _currentUser!.lastAccuracyMeters,
        )) {
      final lat = _currentUser!.lastLatitude!;
      final lon = _currentUser!.lastLongitude!;
      final acc = _currentUser!.lastAccuracyMeters ?? 10.0;
      final dist = LocationService.calculateDistanceMeters(
        lat1: lat,
        lon1: lon,
        lat2: baseLat,
        lon2: baseLon,
      );
      final inside = (dist + acc) <= _settings.radiusMeters;
      return (
        lat: lat,
        lon: lon,
        accuracy: acc,
        distanceMeters: dist,
        isAtStation: inside,
      );
    }

    // Headless test fallback when running without Firestore / platform channels
    final int minuteSeed = DateTime.now().minute % 5;
    final double microOffset = 0.00004 + (minuteSeed * 0.000015);
    final double currentLat = _simulateInsideGeofence
        ? baseLat + microOffset
        : baseLat + 0.0031;
    final double currentLon = _simulateInsideGeofence
        ? baseLon + microOffset
        : baseLon + 0.0024;
    const double accuracy = 6.5;

    final check = LocationService.evaluateGeofence(
      currentLat: currentLat,
      currentLon: currentLon,
      accuracyMeters: accuracy,
      stationLat: baseLat,
      stationLon: baseLon,
      stationRadiusMeters: _settings.radiusMeters,
      locationServicesEnabled: true,
    );

    return (
      lat: currentLat,
      lon: currentLon,
      accuracy: accuracy,
      distanceMeters: check.distanceMeters,
      isAtStation: check.isEligibleForScan,
    );
  }

  /// Starts or resumes the current user's shift and begins shift-scoped location tracking if enabled
  void startCurrentUserShift() {
    if (_currentUser == null) return;
    final user = _currentUser!;
    final shiftName =
        user.assignedShift?.trim() ??
        (_settings.shiftTimings.keys.isNotEmpty
            ? _settings.shiftTimings.keys.first
            : 'Morning');
    final timeRange = _settings.shiftTimings[shiftName] ?? '9:00 AM - 9:00 PM';
    final shiftId =
        'shift_${shiftName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
    final todayStr = DateFormatter.formatDisplayDate(DateTime.now());
    final readings = _currentPumpReadingsMap();

    final idx = _allShifts.indexWhere(
      (s) =>
          s.id == shiftId ||
          s.shiftName.trim().toLowerCase() == shiftName.toLowerCase(),
    );

    Shift started;
    if (idx != -1) {
      started = _allShifts[idx].copyWith(
        staffId: user.id,
        staffName: user.name,
        businessDate: todayStr,
        timeRange: timeRange,
        status: ShiftStatus.inProgress,
      );
      _allShifts[idx] = started;
    } else {
      started = Shift(
        id: shiftId,
        shiftName: shiftName,
        businessDate: todayStr,
        staffId: user.id,
        staffName: user.name,
        pumpName: _pumps.isNotEmpty ? _pumps.first.name : 'Pump 1',
        status: ShiftStatus.inProgress,
        timeRange: timeRange,
        openingReadingsMl: readings,
        closingReadingsMl: readings,
        testVolumesMl: const {1: 5000, 2: 5000},
        cashHandoverPaise: 0,
      );
      _allShifts.add(started);
    }

    _syncShiftHandoverFromEntries();
    _savePersistedShifts();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('shifts')
            .doc(started.id)
            .set(started.toMap())
            .catchError((_) {});
      } catch (_) {}
    }

    if (_settings.enableLiveLocationTracking) {
      _startMinuteLocationTracker();
      refreshCurrentUserLocation(silent: true);
    }
    notifyListeners();
  }

  /// Acquires real hardware GPS coordinates from the device/browser and syncs to Firestore
  Future<({double lat, double lon, double accuracy})?>
  requestAndSyncRealDeviceLocation({bool allowOutsideShift = false}) async {
    if (!allowOutsideShift && !isLiveLocationTrackingActive) {
      return _lastRealDeviceLocation;
    }
    if (_isFetchingDeviceLocation) return _lastRealDeviceLocation;
    _isFetchingDeviceLocation = true;
    try {
      final fix = await LocationService.fetchRealDevicePosition();
      if (fix != null) {
        _lastRealDeviceLocation = fix;
        if (_currentUser != null &&
            (allowOutsideShift || isLiveLocationTrackingActive)) {
          refreshCurrentUserLocation(
            silent: true,
            allowOutsideShift: allowOutsideShift,
            customLat: fix.lat,
            customLon: fix.lon,
            customAccuracy: fix.accuracy,
          );
        }
      }
      return fix;
    } finally {
      _isFetchingDeviceLocation = false;
    }
  }

  void _startMinuteLocationTracker({bool force = false}) {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (!_settings.enableLiveLocationTracking || !isUserShiftInProgress()) {
      return;
    }
    if (_firestore == null && !force) return;
    _locationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_settings.enableLiveLocationTracking || !isUserShiftInProgress()) {
        _locationTimer?.cancel();
        _locationTimer = null;
        return;
      }
      if (_currentUser != null) {
        if (_firestore != null) {
          requestAndSyncRealDeviceLocation();
        } else {
          refreshCurrentUserLocation(silent: true);
        }
      }
    });
  }

  /// Refreshes the currently authenticated user's live GPS location & syncs to Firestore
  void refreshCurrentUserLocation({
    bool silent = false,
    bool allowOutsideShift = false,
    double? customLat,
    double? customLon,
    double? customAccuracy,
  }) {
    if (_currentUser == null) return;
    if (!allowOutsideShift &&
        !isLiveLocationTrackingActive &&
        customLat == null &&
        customLon == null) {
      return;
    }

    // In production (_firestore != null), acquire genuine device GPS instead of simulated coords
    if (customLat == null && customLon == null && _firestore != null) {
      requestAndSyncRealDeviceLocation(allowOutsideShift: allowOutsideShift);
      if (_lastRealDeviceLocation == null) {
        final bool hasLegacySim = LocationService.isLegacySimulatedCoordinate(
          lat: _currentUser!.lastLatitude,
          lon: _currentUser!.lastLongitude,
          accuracy: _currentUser!.lastAccuracyMeters,
        );
        if (hasLegacySim) {
          final cleaned = _currentUser!.copyWith(
            isOnline: true,
            appVersion: currentPlatformVersionLabel,
            lastSeenAt: DateTime.now(),
            clearLocation: true,
          );
          _currentUser = cleaned;
          final idx = _allUsers.indexWhere((u) => u.id == cleaned.id);
          if (idx != -1) _allUsers[idx] = cleaned;
          _savePersistedUsers();
          notifyListeners();
        }
        return;
      }
      customLat = _lastRealDeviceLocation!.lat;
      customLon = _lastRealDeviceLocation!.lon;
      customAccuracy = _lastRealDeviceLocation!.accuracy;
    }

    final now = DateTime.now();
    final snap = getCurrentLiveLocationSnapshot();
    final double lat = customLat ?? snap.lat;
    final double lon = customLon ?? snap.lon;
    final double acc = customAccuracy ?? snap.accuracy;
    final double dist = customLat != null && customLon != null
        ? LocationService.calculateDistanceMeters(
            lat1: lat,
            lon1: lon,
            lat2: _settings.latitude,
            lon2: _settings.longitude,
          )
        : snap.distanceMeters;
    final bool inside = (dist + acc) <= _settings.radiusMeters;
    final String locName = resolveCoordinateLocationName(lat, lon);

    final updated = _currentUser!.copyWith(
      isOnline: true,
      appVersion: currentPlatformVersionLabel,
      lastSeenAt: now,
      lastLatitude: lat,
      lastLongitude: lon,
      lastDistanceMeters: dist,
      lastAccuracyMeters: acc,
      isAtStation: inside,
      locationUpdatedAt: now,
      lastLocationName: locName,
    );

    _currentUser = updated;
    final idx = _allUsers.indexWhere((u) => u.id == updated.id);
    if (idx != -1) {
      _allUsers[idx] = updated;
    }

    _savePersistedUsers();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('members')
            .doc(updated.id)
            .set(updated.toMap(), SetOptions(merge: true))
            .catchError((_) {});
      } catch (_) {}
    }

    notifyListeners();
  }

  void switchUser(UserProfile user) {
    final now = DateTime.now();
    final versionLabel = currentPlatformVersionLabel;

    // Activate shift dynamically if this user is assigned to a shift
    _activateShiftForLoggedInUser(user);
    final bool shouldTrackLocation =
        _settings.enableLiveLocationTracking && isUserShiftInProgress(user);

    late final UserProfile updated;
    if (!shouldTrackLocation) {
      final bool hasLegacySim = LocationService.isLegacySimulatedCoordinate(
        lat: user.lastLatitude,
        lon: user.lastLongitude,
        accuracy: user.lastAccuracyMeters,
      );
      updated = user.copyWith(
        isOnline: true,
        appVersion: versionLabel,
        lastSeenAt: now,
        clearLocation: hasLegacySim,
      );
    } else if (_firestore == null) {
      final loc = getCurrentLiveLocationSnapshot();
      updated = user.copyWith(
        isOnline: true,
        appVersion: versionLabel,
        lastSeenAt: now,
        lastLatitude: loc.lat,
        lastLongitude: loc.lon,
        lastDistanceMeters: loc.distanceMeters,
        lastAccuracyMeters: loc.accuracy,
        isAtStation: loc.isAtStation,
        locationUpdatedAt: now,
        lastLocationName: resolveCoordinateLocationName(loc.lat, loc.lon),
      );
    } else if (_lastRealDeviceLocation != null) {
      final fix = _lastRealDeviceLocation!;
      final dist = LocationService.calculateDistanceMeters(
        lat1: fix.lat,
        lon1: fix.lon,
        lat2: _settings.latitude,
        lon2: _settings.longitude,
      );
      updated = user.copyWith(
        isOnline: true,
        appVersion: versionLabel,
        lastSeenAt: now,
        lastLatitude: fix.lat,
        lastLongitude: fix.lon,
        lastDistanceMeters: dist,
        lastAccuracyMeters: fix.accuracy,
        isAtStation: (dist + fix.accuracy) <= _settings.radiusMeters,
        locationUpdatedAt: now,
        lastLocationName: resolveCoordinateLocationName(fix.lat, fix.lon),
      );
      requestAndSyncRealDeviceLocation();
    } else {
      final bool hasLegacySim = LocationService.isLegacySimulatedCoordinate(
        lat: user.lastLatitude,
        lon: user.lastLongitude,
        accuracy: user.lastAccuracyMeters,
      );
      updated = user.copyWith(
        isOnline: true,
        appVersion: versionLabel,
        lastSeenAt: now,
        clearLocation: hasLegacySim,
      );
      requestAndSyncRealDeviceLocation();
    }
    _currentUser = updated;
    int idx = _allUsers.indexWhere((u) => u.id == user.id);
    if (idx != -1) {
      _allUsers[idx] = updated;
    }

    // Start 1-minute live location tracking timer only if feature flag is ON and shift is inProgress
    _startMinuteLocationTracker();

    // Persist login state to survive browser reload
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefActiveUserId, user.id);
      _savePersistedUsers();
    });

    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('members')
            .doc(user.id)
            .set(updated.toMap(), SetOptions(merge: true))
            .catchError((_) {});
      } catch (_) {}
    }

    // Live Debugging: Send login log to Firebase and purge logs older than 4 days
    RemoteLoggingService().logInfo(
      'User ${user.name} logged in (${user.role.name}) on $versionLabel',
      screenName: 'StationStateProvider',
      action: 'user_login',
      userId: user.id,
      userRole: user.role.name,
    );
    // Purge older than 4 days for all logins, recording failures if any occur
    RemoteLoggingService().purgeLogsOlderThan(age: const Duration(days: 4));

    notifyListeners();
  }

  void logout() {
    _locationTimer?.cancel();
    _locationTimer = null;
    if (_currentUser != null) {
      final user = _currentUser!;
      final now = DateTime.now();
      int idx = _allUsers.indexWhere((u) => u.id == user.id);
      if (idx != -1) {
        _allUsers[idx] = user.copyWith(isOnline: false, lastSeenAt: now);
      }
      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('members')
              .doc(user.id)
              .update({'isOnline': false, 'lastSeenAt': now.toIso8601String()})
              .catchError((_) {});
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

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  bool isUserOnline(String userId) {
    if (_currentUser?.id == userId) return true;
    final match = _allUsers.firstWhere(
      (u) => u.id == userId,
      orElse: () => const UserProfile(
        id: '',
        name: '',
        phoneNumber: '',
        role: UserRole.shiftStaff,
      ),
    );
    return match.isOnline;
  }

  void toggleGeofenceSimulation() {
    _simulateInsideGeofence = !_simulateInsideGeofence;
    refreshCurrentUserLocation(silent: true);
    notifyListeners();
  }

  void addTransactionEntry(TransactionEntry rawEntry) {
    final cleanTime = (rawEntry.timeString ?? '').trim();
    final entry = cleanTime.isNotEmpty
        ? rawEntry
        : rawEntry.copyWith(
            timeString: DateFormatter.formatDisplayTime(rawEntry.createdAt),
          );
    _entries.removeWhere((e) => e.id == entry.id);
    _entries.insert(0, entry);
    _syncShiftHandoverFromEntries();
    _savePersistedEntries();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('entries')
            .doc(entry.id)
            .set(entry.toMap());
      } catch (_) {}
    }

    // Dynamic notification dispatch
    String notifTitle;
    String notifSub;
    switch (entry.category) {
      case EntryCategory.phonePe:
        notifTitle =
            'PhonePe Payment: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub =
            '${entry.phonePeNumber != null && entry.phonePeNumber!.isNotEmpty ? "Mobile: ${entry.phonePeNumber} • " : ""}Recorded by ${entry.createdBy}';
        break;
      case EntryCategory.card:
        notifTitle =
            'Card Swipe: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = 'Recorded by ${entry.createdBy}';
        break;
      case EntryCategory.cash:
        notifTitle =
            'Cash Payment: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = 'Recorded by ${entry.createdBy}';
        break;
      case EntryCategory.toOwner:
        notifTitle =
            'Cash Handover: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = 'Handed over to owner by ${entry.createdBy}';
        break;
      case EntryCategory.expense:
        notifTitle =
            'Expense: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = '${entry.reference ?? "Expense"} • by ${entry.createdBy}';
        break;
      case EntryCategory.credit:
        notifTitle =
            'Credit Sale: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub =
            '${entry.reference ?? "Credit customer"} • by ${entry.createdBy}';
        break;
      default:
        notifTitle =
            '${entry.category.displayName}: ${CurrencyFormatter.formatPaise(entry.amountPaise)}';
        notifSub = 'Recorded by ${entry.createdBy}';
    }
    addNotification(title: notifTitle, subtitle: notifSub);

    notifyListeners();
  }

  void updateTransactionEntry(TransactionEntry updatedEntry) {
    int idx = _entries.indexWhere((e) => e.id == updatedEntry.id);
    if (idx != -1) {
      _entries[idx] = updatedEntry;
      _syncShiftHandoverFromEntries();
      _savePersistedEntries();
      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('entries')
              .doc(updatedEntry.id)
              .set(updatedEntry.toMap());
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> deleteTransactionEntry(String entryId) async {
    final cleanId = entryId.trim();
    if (cleanId.isEmpty) return;

    final existing = _entries.where((e) => e.id == cleanId).firstOrNull;
    _entries.removeWhere((e) => e.id == cleanId);
    _syncShiftHandoverFromEntries();

    final updatedDeletedIds = <String>{
      ..._settings.deletedEntryIds,
      cleanId,
    }.toList();
    _settings = _settings.copyWith(deletedEntryIds: updatedDeletedIds);

    _savePersistedEntries();
    _savePersistedSettings();

    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('entries')
            .doc(cleanId)
            .delete()
            .catchError((_) {});
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('settings')
            .doc('general')
            .set(_settings.toMap())
            .catchError((_) {});
      } catch (_) {}
    }

    if (existing != null) {
      addNotification(
        title:
            'Entry Deleted: ${existing.formattedAmount} (${existing.category.displayName})',
        subtitle:
            'Removed by ${currentUser.name} • Originally recorded by ${existing.createdBy}',
        isWarning: true,
      );
    }

    notifyListeners();
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
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('notifications')
            .doc(notif.id)
            .set(notif.toMap())
            .catchError((_) {});
      } catch (_) {}
    }
    notifyListeners();
  }

  void saveReceiptScan(ReceiptScan inputScan) {
    // Refresh current user's live location if tracking is enabled
    if (isLiveLocationTrackingActive) {
      refreshCurrentUserLocation(silent: true);
    }
    final isOwner = inputScan.capturedBy.toLowerCase().contains('owner');
    late final ReceiptScan scan;
    if (_firestore == null) {
      final loc = getCurrentLiveLocationSnapshot();
      final sLat = inputScan.scanLatitude ?? loc.lat;
      final sLon = inputScan.scanLongitude ?? loc.lon;
      scan = inputScan.copyWith(
        scanLatitude: sLat,
        scanLongitude: sLon,
        scanAccuracyMeters: inputScan.scanAccuracyMeters ?? loc.accuracy,
        scanLocationName:
            inputScan.scanLocationName ??
            resolveCoordinateLocationName(sLat, sLon),
        distanceMeters: inputScan.scanLatitude != null
            ? inputScan.distanceMeters
            : loc.distanceMeters,
        locationVerified: inputScan.scanLatitude != null
            ? inputScan.locationVerified
            : loc.isAtStation,
        reviewStatus: isOwner && inputScan.reviewStatus != 'approved'
            ? 'approved'
            : inputScan.reviewStatus,
        statusMessage: isOwner && inputScan.reviewStatus != 'approved'
            ? 'Direct owner totaliser receipt recorded.'
            : inputScan.statusMessage,
      );
    } else {
      final double? realLat =
          inputScan.scanLatitude ??
          _lastRealDeviceLocation?.lat ??
          _currentUser?.lastLatitude;
      final double? realLon =
          inputScan.scanLongitude ??
          _lastRealDeviceLocation?.lon ??
          _currentUser?.lastLongitude;
      final double? realAcc =
          inputScan.scanAccuracyMeters ??
          _lastRealDeviceLocation?.accuracy ??
          _currentUser?.lastAccuracyMeters;
      final double realDist = (realLat != null && realLon != null)
          ? LocationService.calculateDistanceMeters(
              lat1: realLat,
              lon1: realLon,
              lat2: _settings.latitude,
              lon2: _settings.longitude,
            )
          : inputScan.distanceMeters;
      final bool realInside = (realLat != null && realLon != null)
          ? (realDist + (realAcc ?? 10.0)) <= _settings.radiusMeters
          : inputScan.locationVerified;
      scan = inputScan.copyWith(
        scanLatitude: realLat,
        scanLongitude: realLon,
        scanAccuracyMeters: realAcc,
        scanLocationName:
            inputScan.scanLocationName ??
            ((realLat != null && realLon != null)
                ? resolveCoordinateLocationName(realLat, realLon)
                : null),
        distanceMeters: realDist,
        locationVerified: realInside,
        reviewStatus: isOwner && inputScan.reviewStatus != 'approved'
            ? 'approved'
            : inputScan.reviewStatus,
        statusMessage: isOwner && inputScan.reviewStatus != 'approved'
            ? 'Direct owner totaliser receipt recorded.'
            : inputScan.statusMessage,
      );
    }

    _receipts.removeWhere((r) => r.id == scan.id);
    _receipts.insert(0, scan);
    _savePersistedReceipts();

    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('scanAttempts')
            .doc(scan.id)
            .set(scan.toMap());
      } catch (_) {}

      // If hardware GPS fix was still resolving at the instant of save and tracking is active, patch scan once acquired
      if ((scan.scanLatitude == null || scan.scanLongitude == null) &&
          _settings.enableLiveLocationTracking) {
        requestAndSyncRealDeviceLocation(allowOutsideShift: true).then((fix) {
          if (fix != null) {
            final dist = LocationService.calculateDistanceMeters(
              lat1: fix.lat,
              lon1: fix.lon,
              lat2: _settings.latitude,
              lon2: _settings.longitude,
            );
            final inside = (dist + fix.accuracy) <= _settings.radiusMeters;
            final rIdx = _receipts.indexWhere((r) => r.id == scan.id);
            if (rIdx != -1) {
              final patched = _receipts[rIdx].copyWith(
                scanLatitude: fix.lat,
                scanLongitude: fix.lon,
                scanAccuracyMeters: fix.accuracy,
                scanLocationName: resolveCoordinateLocationName(
                  fix.lat,
                  fix.lon,
                ),
                distanceMeters: dist,
                locationVerified: inside,
              );
              _receipts[rIdx] = patched;
              _savePersistedReceipts();
              try {
                _firestore!
                    .collection('stations')
                    .doc('chatrai')
                    .collection('scanAttempts')
                    .doc(patched.id)
                    .set(patched.toMap(), SetOptions(merge: true));
              } catch (_) {}
              notifyListeners();
            }
          }
        });
      }
    }

    // Dynamic totaliser update for matching pump
    int pumpIdx = _pumps.indexWhere(
      (p) =>
          p.serialNumber == scan.pumpSerialNumber ||
          p.id == 'pump_${scan.fpId}' ||
          p.name.toLowerCase().contains('pump ${scan.fpId}'.toLowerCase()),
    );

    if (pumpIdx != -1) {
      Pump pump = _pumps[pumpIdx];
      List<Nozzle> updatedNozzles = pump.nozzles.map((nozzle) {
        if (scan.nozzleCumVolumeMl.containsKey(nozzle.nozzleNumber)) {
          int newReadingMl = scan.nozzleCumVolumeMl[nozzle.nozzleNumber]!;
          int? newRate = scan.nozzleRatesPaisePerLitre?[nozzle.nozzleNumber];
          return nozzle.copyWith(
            previousAcceptedReadingMl: nozzle.currentTotaliserMl,
            currentTotaliserMl: newReadingMl,
            previousReadingTimestamp: scan.capturedAt,
            ratePaisePerLitre: (newRate != null && newRate > 0)
                ? newRate
                : nozzle.ratePaisePerLitre,
          );
        }
        return nozzle;
      }).toList();

      Pump updatedPump = pump.copyWith(nozzles: updatedNozzles);
      _pumps[pumpIdx] = updatedPump;
      _savePersistedPumps();

      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('pumps')
              .doc(updatedPump.id)
              .set(updatedPump.toMap());
        } catch (_) {}
      }
    }

    // Update active shift closing readings
    int shiftIdx = _allShifts.indexWhere((s) => s.id == activeShift.id);
    if (shiftIdx != -1) {
      Map<int, int> closing = Map.from(_allShifts[shiftIdx].closingReadingsMl);
      scan.nozzleCumVolumeMl.forEach((k, v) => closing[k] = v);
      _allShifts[shiftIdx] = _allShifts[shiftIdx].copyWith(
        closingReadingsMl: closing,
      );
    }

    addNotification(
      title: 'Receipt Captured: Pump ${scan.fpId}',
      subtitle:
          'By ${scan.capturedBy} • ${scan.printedDate} ${scan.printedTime}',
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
            currentTotaliserMl: n.currentTotaliserMl < n1Ml
                ? n1Ml
                : n.currentTotaliserMl,
          );
        } else if (n.nozzleNumber == 2) {
          return n.copyWith(
            previousAcceptedReadingMl: n2Ml,
            currentTotaliserMl: n.currentTotaliserMl < n2Ml
                ? n2Ml
                : n.currentTotaliserMl,
          );
        }
        return n;
      }).toList();

      _pumps[idx] = pump.copyWith(nozzles: updatedNozzles);
      _savePersistedPumps();

      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('pumps')
              .doc(pumpId)
              .set(_pumps[idx].toMap());
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
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('pumps')
              .doc(pumpId)
              .update({'referenceReceiptAsset': imagePath});
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
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('pumps')
            .doc(pump.id)
            .set(pump.toMap())
            .catchError((_) {});
      } catch (_) {}
    }
    addNotification(
      title: 'New Pump Added: ${pump.name}',
      subtitle:
          'Serial No: ${pump.serialNumber} with ${pump.nozzles.length} nozzles',
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
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('pumps')
              .doc(updatedPump.id)
              .set(updatedPump.toMap())
              .catchError((_) {});
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
    final pump = _pumps.firstWhere(
      (p) => p.id == pumpId,
      orElse: () =>
          Pump(id: pumpId, name: 'Pump', serialNumber: '', nozzles: const []),
    );
    _pumps.removeWhere((p) => p.id == pumpId);
    _savePersistedPumps();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('pumps')
            .doc(pumpId)
            .delete()
            .catchError((_) {});
      } catch (_) {}
    }
    addNotification(
      title: 'Pump Removed: ${pump.name}',
      subtitle: 'Dispenser was deleted by owner',
      isWarning: true,
    );
    notifyListeners();
  }

  void submitShiftForReview(
    int cashHandoverPaise, {
    String handoverReceiver = 'Owner',
    String? note,
  }) {
    final currentActive = activeShift;
    int idx = _allShifts.indexWhere((s) => s.id == currentActive.id);
    if (idx == -1 && _allShifts.isNotEmpty) {
      idx = 0;
    }

    final Shift baseShift = idx != -1 ? _allShifts[idx] : currentActive;
    final int effectiveHandoverPaise = cashHandoverPaise > 0
        ? cashHandoverPaise
        : getShiftHandoverToOwnerPaise(baseShift, date: DateTime.now());

    final updated = baseShift.copyWith(
      status: ShiftStatus.needsReview,
      cashHandoverPaise: effectiveHandoverPaise,
      handoverReceiver: handoverReceiver,
      handoverTime: DateTime.now(),
      note: note ?? 'Submitted by ${baseShift.staffName} for owner review',
    );

    if (idx != -1) {
      _allShifts[idx] = updated;
    } else {
      _allShifts.add(updated);
    }

    // Stop live location tracking immediately when shift is closed/submitted
    _locationTimer?.cancel();
    _locationTimer = null;

    _selectedReviewShiftId = updated.id;
    _savePersistedShifts();

    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('shifts')
            .doc(updated.id)
            .set(updated.toMap())
            .catchError((_) {});
      } catch (_) {}
    }

    addNotification(
      title: 'Shift Approval Requested: ${updated.shiftName} Shift',
      subtitle:
          '${updated.staffName} (${updated.pumpName}) • Handover: ${CurrencyFormatter.formatPaise(effectiveHandoverPaise)} to $handoverReceiver',
      isWarning: true,
    );
    notifyListeners();
  }

  void approveShift(String shiftId, {String? ownerNote}) {
    int idx = _allShifts.indexWhere((s) => s.id == shiftId);
    if (idx != -1) {
      final current = _allShifts[idx];
      final updated = current.copyWith(
        status: ShiftStatus.approved,
        note:
            ownerNote ??
            'Approved by ${currentUser.name} at ${DateFormatter.formatTimeIST(DateTime.now())}',
      );
      _allShifts[idx] = updated;
      _savePersistedShifts();

      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('shifts')
              .doc(updated.id)
              .set(updated.toMap())
              .catchError((_) {});
        } catch (_) {}
      }

      addNotification(
        title: 'Shift Approved: ${updated.shiftName} Shift',
        subtitle:
            '${updated.staffName} (${updated.pumpName}) • Handover: ${updated.formattedHandover} verified by ${currentUser.name}',
      );
      notifyListeners();
    }
  }

  void rejectShift(String shiftId, {String? reason}) {
    int idx = _allShifts.indexWhere((s) => s.id == shiftId);
    if (idx != -1) {
      final current = _allShifts[idx];
      final cleanReason = (reason != null && reason.trim().isNotEmpty)
          ? reason.trim()
          : 'Returned by ${currentUser.name} for correction';
      final updated = current.copyWith(
        status: ShiftStatus.inProgress,
        note: cleanReason,
      );
      _allShifts[idx] = updated;
      _savePersistedShifts();

      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('shifts')
              .doc(updated.id)
              .set(updated.toMap())
              .catchError((_) {});
        } catch (_) {}
      }

      addNotification(
        title: 'Shift Returned for Correction: ${updated.shiftName}',
        subtitle: '${updated.staffName} • $cleanReason',
        isWarning: true,
      );
      notifyListeners();
    }
  }

  // --- Hierarchical Cash Handover Rules & Workflow ---

  /// Enforces strict organizational hierarchy for cash handovers:
  /// - No one can ever hand over cash to oneself or to Shift Staff.
  /// - Shift Staff can hand over cash upwards to Manager, Admin, or Owner.
  /// - Manager can ONLY hand over cash upwards to Admin or Owner (never to Shift Staff or another Manager).
  /// - Owner / Admin can only hand over cash to another Owner or Admin.
  bool canUserHandoverTo(UserProfile sender, UserProfile receiver) {
    if (!receiver.active || receiver.isPendingApproval) return false;
    if (sender.id == receiver.id ||
        sender.name.trim().toLowerCase() ==
            receiver.name.trim().toLowerCase()) {
      return false;
    }
    // Never allow handing over cash to Shift Staff
    if (receiver.role == UserRole.shiftStaff) return false;

    if (sender.role == UserRole.manager) {
      // Manager can ONLY hand over cash upwards to Owner or Admin
      return receiver.hasOwnerPrivileges;
    }

    if (sender.hasOwnerPrivileges) {
      // Owner/Admin can only hand over to another Owner/Admin
      return receiver.hasOwnerPrivileges;
    }

    // Shift Staff can hand over upwards to Manager, Admin, or Owner
    return receiver.role == UserRole.manager || receiver.hasOwnerPrivileges;
  }

  /// Returns eligible handover receiver profiles strictly following role hierarchy for [sender] (defaults to [currentUser]).
  List<UserProfile> getEligibleHandoverReceivers([UserProfile? sender]) {
    final actor = sender ?? currentUser;
    final eligible = _allUsers
        .where(
          (u) => !_isDummyUser(u.id, u.name) && canUserHandoverTo(actor, u),
        )
        .toList();
    // Sort: for Shift Staff, show Managers first then Owners/Admins; for Manager/Owner, show Owners/Admins
    eligible.sort((a, b) {
      if (actor.role == UserRole.shiftStaff) {
        final aTier = a.role == UserRole.manager ? 0 : 1;
        final bTier = b.role == UserRole.manager ? 0 : 1;
        if (aTier != bTier) return aTier.compareTo(bTier);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return eligible;
  }

  /// Returns ONLY the clean person names (without role prefixes or nameless placeholders)
  /// of eligible handover receivers following the strict role hierarchy.
  List<String> getEligibleHandoverReceiverNames([UserProfile? sender]) {
    final names = <String>[];
    for (final u in getEligibleHandoverReceivers(sender)) {
      final clean = u.name.trim();
      if (clean.isNotEmpty && !names.contains(clean)) {
        names.add(clean);
      }
    }
    return names;
  }

  /// Pending cash handovers addressed to the currently logged-in user (or any Owner/Admin if addressed to an Owner/Admin)
  List<CashHandoverRecord> get incomingPendingHandoversForCurrentUser {
    final actor = currentUser;
    final actorNameLower = actor.name.trim().toLowerCase();
    return _cashHandovers.where((h) {
      if (h.status != CashHandoverStatus.pending) return false;
      if (h.toUserId == actor.id ||
          h.toUserName.trim().toLowerCase() == actorNameLower) {
        return true;
      }
      if (actor.hasOwnerPrivileges &&
          (h.toUserRole == 'owner' || h.toUserRole == 'admin')) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Cash handovers initiated by the currently logged-in user
  List<CashHandoverRecord> get currentUserSentHandovers {
    final actor = currentUser;
    final actorNameLower = actor.name.trim().toLowerCase();
    return _cashHandovers.where((h) {
      return h.fromUserId == actor.id ||
          h.fromUserName.trim().toLowerCase() == actorNameLower;
    }).toList();
  }

  /// Cash handovers accepted by the current Manager from Shift Staff that have not yet been forwarded to an Owner/Admin
  List<CashHandoverRecord> get managerUnforwardedHandoversForCurrentUser {
    final actor = currentUser;
    if (actor.role != UserRole.manager) return const [];
    final actorNameLower = actor.name.trim().toLowerCase();
    return _cashHandovers.where((h) {
      return h.status == CashHandoverStatus.accepted &&
          (h.toUserId == actor.id ||
              h.toUserName.trim().toLowerCase() == actorNameLower);
    }).toList();
  }

  /// Total cash (in paise) accepted by the current Manager from Shift Staff and ready to handover to Owner/Admin
  int get managerAcceptedCashFromStaffPaise {
    int sum = 0;
    for (final h in managerUnforwardedHandoversForCurrentUser) {
      sum += h.amountPaise;
    }
    return sum;
  }

  /// Initiates a hierarchy-validated Cash Handover workflow record (and optionally records a Paid out -> To owner entry).
  CashHandoverRecord? initiateCashHandover({
    required String receiverName,
    required int amountPaise,
    String? note,
    String? timeString,
    bool createTransactionEntry = true,
  }) {
    if (amountPaise <= 0) return null;
    final actor = currentUser;
    final eligible = getEligibleHandoverReceivers(actor);
    final cleanTarget = receiverName.trim().toLowerCase();

    final receiverUser = eligible.where((u) {
      final n = u.name.trim().toLowerCase();
      return n == cleanTarget || cleanTarget.contains(n);
    }).firstOrNull;

    // Strictly reject if receiver is not eligible under hierarchy rules
    if (receiverUser == null || !canUserHandoverTo(actor, receiverUser)) {
      return null;
    }

    final now = DateTime.now();
    final resolvedTime = (timeString != null && timeString.trim().isNotEmpty)
        ? timeString.trim()
        : DateFormatter.formatDisplayTime(now);
    final cleanNote = (note ?? '').trim();
    final String entryId = 'entry_ho_${now.millisecondsSinceEpoch}';

    if (createTransactionEntry) {
      final refText = cleanNote.isNotEmpty
          ? 'To ${receiverUser.name} ($cleanNote)'
          : 'Handover to ${receiverUser.name}';
      final entry = TransactionEntry(
        id: entryId,
        shiftId: activeShift.id,
        category: EntryCategory.toOwner,
        direction: EntryDirection.paidOut,
        amountPaise: amountPaise,
        timeString: resolvedTime,
        reference: refText.length > 30 ? refText.substring(0, 30) : refText,
        createdAt: now,
        createdBy: actor.name,
        status: 'Needs review',
      );
      _entries.removeWhere((e) => e.id == entry.id);
      _entries.insert(0, entry);
      _syncShiftHandoverFromEntries();
      _savePersistedEntries();
      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('entries')
              .doc(entry.id)
              .set(entry.toMap())
              .catchError((_) {});
        } catch (_) {}
      }
    }

    final record = CashHandoverRecord(
      id: 'handover_${now.millisecondsSinceEpoch}',
      shiftId: activeShift.id,
      shiftName: activeShift.shiftName,
      businessDate: activeShift.businessDate,
      fromUserId: actor.id,
      fromUserName: actor.name,
      fromUserRole: actor.role.name,
      toUserId: receiverUser.id,
      toUserName: receiverUser.name,
      toUserRole: receiverUser.role.name,
      amountPaise: amountPaise,
      status: CashHandoverStatus.pending,
      createdAt: now,
      timeString: resolvedTime,
      note: cleanNote.isNotEmpty ? cleanNote : null,
      linkedEntryId: createTransactionEntry ? entryId : null,
    );

    _cashHandovers.removeWhere((h) => h.id == record.id);
    _cashHandovers.insert(0, record);
    _savePersistedCashHandovers();

    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('cashHandovers')
            .doc(record.id)
            .set(record.toMap())
            .catchError((_) {});
      } catch (_) {}
    }

    addNotification(
      title:
          'Cash Handover Sent: ${CurrencyFormatter.formatPaise(amountPaise)}',
      subtitle:
          '${actor.name} → ${receiverUser.name} • Awaiting ${receiverUser.name} confirmation',
      isWarning: true,
    );
    notifyListeners();
    return record;
  }

  /// Receiver (Manager, Admin, or Owner) accepts and verifies an incoming Cash Handover.
  void acceptCashHandover(String handoverId) {
    final idx = _cashHandovers.indexWhere((h) => h.id == handoverId);
    if (idx == -1) return;

    final existing = _cashHandovers[idx];
    final updated = existing.copyWith(
      status: CashHandoverStatus.accepted,
      respondedAt: DateTime.now(),
    );
    _cashHandovers[idx] = updated;
    _savePersistedCashHandovers();

    if (existing.linkedEntryId != null && existing.linkedEntryId!.isNotEmpty) {
      final eIdx = _entries.indexWhere((e) => e.id == existing.linkedEntryId);
      if (eIdx != -1) {
        _entries[eIdx] = _entries[eIdx].copyWith(status: 'Approved');
        _savePersistedEntries();
        if (_firestore != null) {
          try {
            _firestore!
                .collection('stations')
                .doc('chatrai')
                .collection('entries')
                .doc(_entries[eIdx].id)
                .set(_entries[eIdx].toMap(), SetOptions(merge: true))
                .catchError((_) {});
          } catch (_) {}
        }
      }
    }

    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('cashHandovers')
            .doc(updated.id)
            .set(updated.toMap(), SetOptions(merge: true))
            .catchError((_) {});
      } catch (_) {}
    }

    addNotification(
      title: 'Cash Handover Verified: ${updated.formattedAmount}',
      subtitle: 'Accepted by ${currentUser.name} from ${updated.fromUserName}',
    );
    notifyListeners();
  }

  /// Receiver rejects/returns a pending Cash Handover.
  void rejectCashHandover(String handoverId, {String? reason}) {
    final idx = _cashHandovers.indexWhere((h) => h.id == handoverId);
    if (idx == -1) return;

    final existing = _cashHandovers[idx];
    final cleanReason = (reason != null && reason.trim().isNotEmpty)
        ? reason.trim()
        : 'Rejected by ${currentUser.name}';
    final updated = existing.copyWith(
      status: CashHandoverStatus.rejected,
      respondedAt: DateTime.now(),
      note: cleanReason,
    );
    _cashHandovers[idx] = updated;
    _savePersistedCashHandovers();

    if (existing.linkedEntryId != null && existing.linkedEntryId!.isNotEmpty) {
      _entries.removeWhere((e) => e.id == existing.linkedEntryId);
      _syncShiftHandoverFromEntries();
      _savePersistedEntries();
      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('entries')
              .doc(existing.linkedEntryId!)
              .delete()
              .catchError((_) {});
        } catch (_) {}
      }
    }

    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('cashHandovers')
            .doc(updated.id)
            .set(updated.toMap(), SetOptions(merge: true))
            .catchError((_) {});
      } catch (_) {}
    }

    addNotification(
      title: 'Cash Handover Returned: ${updated.formattedAmount}',
      subtitle:
          'Returned to ${updated.fromUserName} by ${currentUser.name} • $cleanReason',
      isWarning: true,
    );
    notifyListeners();
  }

  /// Manager forwards an accepted Staff Cash Handover upwards to an Owner or Admin.
  CashHandoverRecord? forwardHandoverToOwner(
    String sourceHandoverId, {
    required String ownerReceiverName,
    String? note,
  }) {
    final idx = _cashHandovers.indexWhere((h) => h.id == sourceHandoverId);
    if (idx == -1) return null;
    final source = _cashHandovers[idx];

    final forwardedRecord = initiateCashHandover(
      receiverName: ownerReceiverName,
      amountPaise: source.amountPaise,
      note: note ?? 'Forwarded from ${source.fromUserName}',
      createTransactionEntry: false,
    );
    if (forwardedRecord == null) return null;

    final updatedSource = source.copyWith(
      status: CashHandoverStatus.forwarded,
      respondedAt: DateTime.now(),
    );
    final newIdx = _cashHandovers.indexWhere((h) => h.id == sourceHandoverId);
    if (newIdx != -1) {
      _cashHandovers[newIdx] = updatedSource;
    }
    _savePersistedCashHandovers();

    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('cashHandovers')
            .doc(updatedSource.id)
            .set(updatedSource.toMap(), SetOptions(merge: true))
            .catchError((_) {});
      } catch (_) {}
    }

    notifyListeners();
    return forwardedRecord;
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
      reference: cleanSubtitle.isNotEmpty
          ? '$cleanName ($cleanSubtitle)'
          : cleanName,
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
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('creditCustomers')
              .doc(updated.id)
              .set(updated.toMap())
              .catchError((_) {});
        } catch (_) {}
      }
    } else {
      final newCust = CreditCustomer(
        id: 'cust_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanName,
        subtitle: cleanSubtitle.isNotEmpty
            ? cleanSubtitle
            : 'Customer on Credit',
        pendingAmountPaise: amountPaise,
        lastCreditDate: DateTime.now(),
        payments: const [],
      );
      _creditCustomers.insert(0, newCust);
      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('creditCustomers')
              .doc(newCust.id)
              .set(newCust.toMap())
              .catchError((_) {});
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
      int updatedPending = (cust.pendingAmountPaise - amountPaise)
          .clamp(0, double.infinity)
          .toInt();
      final newPayment = CreditPayment(
        id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        amountPaise: amountPaise,
        mode: mode,
      );
      final updatedPayments = List<CreditPayment>.from(cust.payments)
        ..add(newPayment);
      final updated = cust.copyWith(
        pendingAmountPaise: updatedPending,
        payments: updatedPayments,
      );
      _creditCustomers[idx] = updated;
      _savePersistedCreditCustomers();
      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('creditCustomers')
              .doc(updated.id)
              .set(updated.toMap())
              .catchError((_) {});
        } catch (_) {}
      }
      addNotification(
        title:
            'Credit Payment: ${CurrencyFormatter.formatPaise(amountPaise)} by ${cust.name}',
        subtitle:
            'Mode: $mode • Remaining: ${CurrencyFormatter.formatPaise(updatedPending)}',
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
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('scanAttempts')
              .doc(scanId)
              .update({
                'reviewStatus': 'approved',
                'statusMessage': 'Approved by Owner.',
              })
              .catchError((_) {});
        } catch (_) {}
      }

      // Update nozzle totalisers with approved readings
      int pumpIdx = _pumps.indexWhere(
        (p) =>
            p.serialNumber == approved.pumpSerialNumber ||
            p.id == 'pump_${approved.fpId}' ||
            p.name.toLowerCase().contains(
              'pump ${approved.fpId}'.toLowerCase(),
            ),
      );

      if (pumpIdx != -1) {
        Pump pump = _pumps[pumpIdx];
        List<Nozzle> updatedNozzles = pump.nozzles.map((nozzle) {
          if (approved.nozzleCumVolumeMl.containsKey(nozzle.nozzleNumber)) {
            int newReadingMl = approved.nozzleCumVolumeMl[nozzle.nozzleNumber]!;
            int? newRate =
                approved.nozzleRatesPaisePerLitre?[nozzle.nozzleNumber];
            return nozzle.copyWith(
              previousAcceptedReadingMl: nozzle.currentTotaliserMl,
              currentTotaliserMl: newReadingMl,
              previousReadingTimestamp: approved.capturedAt,
              ratePaisePerLitre: (newRate != null && newRate > 0)
                  ? newRate
                  : nozzle.ratePaisePerLitre,
            );
          }
          return nozzle;
        }).toList();

        Pump updatedPump = pump.copyWith(nozzles: updatedNozzles);
        _pumps[pumpIdx] = updatedPump;
        _savePersistedPumps();

        if (_firestore != null) {
          try {
            _firestore!
                .collection('stations')
                .doc('chatrai')
                .collection('pumps')
                .doc(updatedPump.id)
                .set(updatedPump.toMap())
                .catchError((_) {});
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
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('scanAttempts')
              .doc(scanId)
              .update({
                'reviewStatus': 'rejected',
                'statusMessage': 'Rejected by Owner. Please rescan.',
              })
              .catchError((_) {});
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
    _startMinuteLocationTracker();
    _savePersistedSettings();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('settings')
            .doc('general')
            .set(newSettings.toMap())
            .catchError((_) {});
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .set({
              'stationName': newSettings.stationName,
              'latitude': newSettings.latitude,
              'longitude': newSettings.longitude,
              'radiusMeters': newSettings.radiusMeters,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .catchError((_) {});
      } catch (_) {}
    }
    addNotification(
      title: 'Station Settings Updated',
      subtitle:
          '${newSettings.stationName} (${newSettings.latitude.toStringAsFixed(4)}° N, ${newSettings.longitude.toStringAsFixed(4)}° E)',
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
    List<CategoryItem> updated = _settings.categories
        .map((c) => c.id == category.id ? category : c)
        .toList();
    updateSettings(_settings.copyWith(categories: updated));
  }

  void deleteCategory(String categoryId) {
    List<CategoryItem> updated = _settings.categories
        .where((c) => c.id != categoryId)
        .toList();
    updateSettings(_settings.copyWith(categories: updated));
  }

  // --- Roles & Screen Permissions Management (Owner Configurable) ---
  List<String> getAllowedScreensForUser([UserProfile? user]) {
    return _settings.getScreensForUser(user ?? currentUser);
  }

  bool canAccessScreen(String screenId, [UserProfile? user]) {
    return getAllowedScreensForUser(user).contains(screenId);
  }

  void updateRoleScreenPermissions(String roleKey, List<String> screenIds) {
    final validIds = StationSettings.allScreenPermissions
        .map((s) => s.id)
        .toSet();
    final cleaned = screenIds
        .where((id) => validIds.contains(id))
        .toSet()
        .toList();
    if (roleKey == 'owner' || roleKey == 'admin') {
      for (final req in [
        'station_overview',
        'people_management',
        'station_settings',
      ]) {
        if (!cleaned.contains(req)) cleaned.add(req);
      }
    }
    if (cleaned.isEmpty) {
      cleaned.add(roleKey == 'manager' ? 'people_management' : 'my_shift');
    }

    final updatedMap = {
      for (final entry in _settings.roleScreenPermissions.entries)
        entry.key: List<String>.from(entry.value),
    };
    updatedMap[roleKey] = cleaned;

    final updatedCustomRoles = _settings.customRoles.map((r) {
      if (r.id == roleKey) {
        return r.copyWith(screenPermissions: cleaned);
      }
      return r;
    }).toList();

    _settings = _settings.copyWith(
      roleScreenPermissions: updatedMap,
      customRoles: updatedCustomRoles,
    );
    _savePersistedSettings();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('settings')
            .doc('general')
            .set(_settings.toMap(), SetOptions(merge: true))
            .catchError((_) {});
      } catch (_) {}
    }
    notifyListeners();
  }

  void toggleRoleScreenPermission(
    String roleKey,
    String screenId,
    bool enabled,
  ) {
    final currentList = List<String>.from(
      _settings.roleScreenPermissions[roleKey] ??
          StationSettings.defaultRoleScreenPermissions[roleKey] ??
          const ['my_shift'],
    );
    if (enabled) {
      if (!currentList.contains(screenId)) {
        currentList.add(screenId);
      }
    } else {
      // Prevent disabling core Owner admin screens on Owner role
      if (roleKey == 'owner' &&
          const [
            'station_overview',
            'people_management',
            'station_settings',
          ].contains(screenId)) {
        return;
      }
      if (currentList.length > 1) {
        currentList.remove(screenId);
      }
    }
    updateRoleScreenPermissions(roleKey, currentList);
  }

  void resetRoleScreenPermissionsToDefault([String? roleKey]) {
    final updatedMap = {
      for (final entry in _settings.roleScreenPermissions.entries)
        entry.key: List<String>.from(entry.value),
    };
    if (roleKey != null) {
      if (StationSettings.defaultRoleScreenPermissions.containsKey(roleKey)) {
        updatedMap[roleKey] = List<String>.from(
          StationSettings.defaultRoleScreenPermissions[roleKey]!,
        );
      } else {
        final custom = _settings.customRoles
            .where((r) => r.id == roleKey)
            .firstOrNull;
        if (custom != null) {
          final fallbackBase = custom.hasOwnerPrivileges
              ? 'admin'
              : custom.baseRole;
          updatedMap[roleKey] = List<String>.from(
            StationSettings.defaultRoleScreenPermissions[fallbackBase] ??
                const ['my_shift'],
          );
        }
      }
    } else {
      for (final entry
          in StationSettings.defaultRoleScreenPermissions.entries) {
        updatedMap[entry.key] = List<String>.from(entry.value);
      }
    }
    _settings = _settings.copyWith(roleScreenPermissions: updatedMap);
    _savePersistedSettings();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('settings')
            .doc('general')
            .set(_settings.toMap(), SetOptions(merge: true))
            .catchError((_) {});
      } catch (_) {}
    }
    notifyListeners();
  }

  void addOrUpdateCustomRole(CustomRoleItem role) {
    final validIds = StationSettings.allScreenPermissions
        .map((s) => s.id)
        .toSet();
    final cleanedScreens = role.screenPermissions
        .where((id) => validIds.contains(id))
        .toSet()
        .toList();
    if (cleanedScreens.isEmpty) {
      final fallbackBase = role.hasOwnerPrivileges ? 'admin' : role.baseRole;
      cleanedScreens.addAll(
        StationSettings.defaultRoleScreenPermissions[fallbackBase] ??
            const ['my_shift'],
      );
    }
    final normalizedRole = role.copyWith(screenPermissions: cleanedScreens);

    final updatedCustom = List<CustomRoleItem>.from(_settings.customRoles);
    final idx = updatedCustom.indexWhere((r) => r.id == normalizedRole.id);
    if (idx >= 0) {
      updatedCustom[idx] = normalizedRole;
    } else {
      updatedCustom.add(normalizedRole);
    }

    final updatedMap = {
      for (final entry in _settings.roleScreenPermissions.entries)
        entry.key: List<String>.from(entry.value),
    };
    updatedMap[normalizedRole.id] = List<String>.from(
      normalizedRole.screenPermissions,
    );

    _settings = _settings.copyWith(
      customRoles: updatedCustom,
      roleScreenPermissions: updatedMap,
    );
    _savePersistedSettings();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('settings')
            .doc('general')
            .set(_settings.toMap(), SetOptions(merge: true))
            .catchError((_) {});
      } catch (_) {}
    }
    addNotification(
      title: 'Role Saved: ${normalizedRole.name}',
      subtitle: normalizedRole.hasOwnerPrivileges
          ? 'Owner / Admin Portal privileges (${normalizedRole.screenPermissions.length} screens)'
          : 'Base tier: ${normalizedRole.baseRole} (${normalizedRole.screenPermissions.length} screens)',
    );
    notifyListeners();
  }

  void deleteCustomRole(String roleId) {
    if (StationSettings.defaultRoleScreenPermissions.containsKey(roleId))
      return;
    final updatedCustom = _settings.customRoles
        .where((r) => r.id != roleId)
        .toList();
    final updatedMap = {
      for (final entry in _settings.roleScreenPermissions.entries)
        if (entry.key != roleId) entry.key: List<String>.from(entry.value),
    };

    // Reassign any user holding this custom role back to its base role
    for (int i = 0; i < _allUsers.length; i++) {
      if (_allUsers[i].customRoleId == roleId) {
        _allUsers[i] = _allUsers[i].copyWith(clearCustomRole: true);
      }
    }

    _settings = _settings.copyWith(
      customRoles: updatedCustom,
      roleScreenPermissions: updatedMap,
    );
    _savePersistedSettings();
    _savePersistedUsers();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('settings')
            .doc('general')
            .set(_settings.toMap(), SetOptions(merge: true))
            .catchError((_) {});
      } catch (_) {}
    }
    notifyListeners();
  }

  // --- Shift Timings & Timing Requests ---
  void _syncShiftsWithTimings() {
    final todayStr = DateFormatter.formatDisplayDate(DateTime.now());
    final validNamesLower = _settings.shiftTimings.keys
        .map((k) => k.trim().toLowerCase())
        .toSet();

    // Remove any shift whose shiftName was deleted from _settings.shiftTimings or belongs to a dummy user
    _allShifts.removeWhere((s) {
      final isInvalidTiming =
          validNamesLower.isNotEmpty &&
          !validNamesLower.contains(s.shiftName.trim().toLowerCase());
      final isDummy = _isDummyUser(s.staffId, s.staffName);
      return isInvalidTiming || isDummy;
    });

    final readings = _currentPumpReadingsMap();

    for (var entry in _settings.shiftTimings.entries) {
      final timingKey = entry.key.trim();
      final timingLower = timingKey.toLowerCase();
      final idx = _allShifts.indexWhere(
        (s) => s.shiftName.trim().toLowerCase() == timingLower,
      );

      // Find real user assigned to this shift
      final assignedUser = _allUsers
          .where(
            (u) =>
                !_isDummyUser(u.id, u.name) &&
                u.assignedShift?.trim().toLowerCase() == timingLower,
          )
          .firstOrNull;

      if (idx != -1) {
        var existing = _allShifts[idx];
        if (existing.timeRange != entry.value) {
          existing = existing.copyWith(timeRange: entry.value);
        }
        if (assignedUser != null &&
            (existing.staffId != assignedUser.id ||
                existing.staffName != assignedUser.name)) {
          existing = existing.copyWith(
            staffId: assignedUser.id,
            staffName: assignedUser.name,
            status:
                isUserOnline(assignedUser.id) &&
                    existing.status == ShiftStatus.scheduled
                ? ShiftStatus.inProgress
                : existing.status,
          );
        }
        _allShifts[idx] = existing;
      } else if (assignedUser != null && isUserOnline(assignedUser.id)) {
        // Only auto-create shift when an assigned user is actually logged in
        _allShifts.add(
          Shift(
            id: 'shift_${timingLower.replaceAll(RegExp(r'\s+'), '_')}',
            shiftName: timingKey,
            businessDate: todayStr,
            staffId: assignedUser.id,
            staffName: assignedUser.name,
            pumpName: _pumps.isNotEmpty ? _pumps.first.name : 'Pump 1',
            status: ShiftStatus.inProgress,
            timeRange: entry.value,
            openingReadingsMl: readings,
            closingReadingsMl: readings,
            testVolumesMl: const {1: 5000, 2: 5000},
            cashHandoverPaise: 0,
          ),
        );
      }
    }
    _savePersistedShifts();
  }

  void addShiftTiming(String shiftName, String timeRange) {
    final cleanName = shiftName.trim();
    final cleanRange = timeRange.trim();
    if (cleanName.isEmpty || cleanRange.isEmpty) return;

    Map<String, String> updated = Map.from(_settings.shiftTimings);
    updated[cleanName] = cleanRange;
    updateSettings(_settings.copyWith(shiftTimings: updated));

    final assignedUser = _allUsers
        .where(
          (u) =>
              !_isDummyUser(u.id, u.name) &&
              u.assignedShift?.trim().toLowerCase() == cleanName.toLowerCase(),
        )
        .firstOrNull;

    int idx = _allShifts.indexWhere(
      (s) => s.shiftName.toLowerCase() == cleanName.toLowerCase(),
    );
    if (idx != -1) {
      _allShifts[idx] = _allShifts[idx].copyWith(timeRange: cleanRange);
      _savePersistedShifts();
      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('shifts')
              .doc(_allShifts[idx].id)
              .set(_allShifts[idx].toMap());
        } catch (_) {}
      }
    } else {
      final shiftId =
          'shift_${cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
      final todayStr = DateFormatter.formatDisplayDate(DateTime.now());
      final readings = _currentPumpReadingsMap();
      final isAssignedOnline =
          assignedUser != null && isUserOnline(assignedUser.id);
      final newShift = Shift(
        id: shiftId,
        shiftName: cleanName,
        businessDate: todayStr,
        staffId: assignedUser?.id ?? 'unassigned',
        staffName: assignedUser?.name ?? 'Unassigned',
        pumpName: _pumps.isNotEmpty ? _pumps.first.name : 'Pump 1',
        status: isAssignedOnline
            ? ShiftStatus.inProgress
            : ShiftStatus.scheduled,
        timeRange: cleanRange,
        openingReadingsMl: readings,
        closingReadingsMl: readings,
        testVolumesMl: const {1: 5000, 2: 5000},
        cashHandoverPaise: 0,
      );
      _allShifts.add(newShift);
      _savePersistedShifts();
      if (_firestore != null && isAssignedOnline) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('shifts')
              .doc(shiftId)
              .set(newShift.toMap());
        } catch (_) {}
      }
    }

    addNotification(
      title: 'Shift Added: $cleanName',
      subtitle: 'Timing: $cleanRange',
    );
    notifyListeners();
  }

  void editShiftTiming(
    String oldShiftName,
    String newShiftName,
    String timeRange,
  ) {
    final cleanOld = oldShiftName.trim();
    final cleanNew = newShiftName.trim();
    final cleanRange = timeRange.trim();
    if (cleanNew.isEmpty || cleanRange.isEmpty) return;

    Map<String, String> updated = {};
    for (var entry in _settings.shiftTimings.entries) {
      if (entry.key.toLowerCase() == cleanOld.toLowerCase()) {
        updated[cleanNew] = cleanRange;
      } else {
        updated[entry.key] = entry.value;
      }
    }
    if (!updated.containsKey(cleanNew)) {
      updated[cleanNew] = cleanRange;
    }
    updateSettings(_settings.copyWith(shiftTimings: updated));

    for (int i = 0; i < _allShifts.length; i++) {
      if (_allShifts[i].shiftName.toLowerCase() == cleanOld.toLowerCase()) {
        _allShifts[i] = _allShifts[i].copyWith(
          shiftName: cleanNew,
          timeRange: cleanRange,
        );
        if (_firestore != null) {
          try {
            _firestore!
                .collection('stations')
                .doc('chatrai')
                .collection('shifts')
                .doc(_allShifts[i].id)
                .set(_allShifts[i].toMap());
          } catch (_) {}
        }
      }
    }
    _savePersistedShifts();

    for (int i = 0; i < _allUsers.length; i++) {
      if (_allUsers[i].assignedShift?.toLowerCase() == cleanOld.toLowerCase()) {
        final updatedU = _allUsers[i].copyWith(assignedShift: cleanNew);
        updateUser(updatedU, bypassApproval: true);
      }
    }

    addNotification(
      title: 'Shift Updated: $cleanNew',
      subtitle: 'Timing: $cleanRange',
    );
    notifyListeners();
  }

  void deleteShiftTiming(String shiftName) {
    final cleanName = shiftName.trim();
    Map<String, String> updated = Map.from(_settings.shiftTimings);
    updated.removeWhere(
      (k, _) => k.trim().toLowerCase() == cleanName.toLowerCase(),
    );
    updateSettings(_settings.copyWith(shiftTimings: updated));

    final removed = _allShifts
        .where(
          (s) => s.shiftName.trim().toLowerCase() == cleanName.toLowerCase(),
        )
        .toList();
    _allShifts.removeWhere(
      (s) => s.shiftName.trim().toLowerCase() == cleanName.toLowerCase(),
    );
    _savePersistedShifts();

    if (_firestore != null) {
      final canonicalShiftId =
          'shift_${cleanName.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}';
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('shifts')
            .doc(canonicalShiftId)
            .delete()
            .catchError((_) {});
      } catch (_) {}
      for (var s in removed) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('shifts')
              .doc(s.id)
              .delete()
              .catchError((_) {});
        } catch (_) {}
      }
    }

    for (int i = 0; i < _allUsers.length; i++) {
      if (_allUsers[i].assignedShift?.trim().toLowerCase() ==
          cleanName.toLowerCase()) {
        final updatedU = _allUsers[i].copyWith(clearAssignedShift: true);
        updateUser(updatedU, bypassApproval: true);
      }
    }

    addNotification(
      title: 'Shift Deleted',
      subtitle: '$cleanName shift removed from the station.',
      isWarning: true,
    );
    notifyListeners();
  }

  void updateShiftTiming(String shiftName, String timeRange) {
    editShiftTiming(shiftName, shiftName, timeRange);
  }

  // --- APK Releases Management ---
  Future<void> publishApkRelease(
    ApkReleaseItem release, {
    bool? forceUpdateOverride,
  }) async {
    _apkReleases.removeWhere((r) => r.id == release.id);
    _apkReleases.insert(0, release);
    await _savePersistedApkReleases();

    final updatedSettings = _settings.copyWith(
      latestVersion: release.version,
      latestBuildNumber: release.buildNumber,
      updateUrl: release.downloadUrl,
      forceUpdate: forceUpdateOverride ?? true,
      releaseNotes: release.releaseNotes,
    );
    updateSettings(updatedSettings);

    if (_firestore != null) {
      try {
        await _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('apkReleases')
            .doc(release.id)
            .set(release.toMap());
      } catch (e) {
        debugPrint('Failed to save APK release in Firestore: $e');
      }
    }

    addNotification(
      title: 'New APK Released (${release.displayVersion})',
      subtitle: release.releaseNotes.isNotEmpty
          ? '${release.releaseNotes} • ${release.downloadUrl}'
          : release.downloadUrl,
    );
    notifyListeners();
  }

  Future<void> deleteApkRelease(String releaseId) async {
    _apkReleases.removeWhere((r) => r.id == releaseId);
    await _savePersistedApkReleases();

    if (_firestore != null) {
      try {
        await _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('apkReleases')
            .doc(releaseId)
            .delete();
      } catch (e) {
        debugPrint('Failed to delete APK release from Firestore: $e');
      }
    }
    notifyListeners();
  }

  Future<int> purgeApkReleasesOlderThan(Duration age) async {
    final cutoff = DateTime.now().subtract(age);
    final toDelete = _apkReleases
        .where((r) => r.publishedAt.isBefore(cutoff))
        .toList();
    if (toDelete.isEmpty) return 0;

    for (final rel in toDelete) {
      _apkReleases.removeWhere((r) => r.id == rel.id);
      if (_firestore != null) {
        try {
          await _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('apkReleases')
              .doc(rel.id)
              .delete();
        } catch (_) {}
      }
    }

    await _savePersistedApkReleases();
    notifyListeners();
    return toDelete.length;
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
        await _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('shiftTimingRequests')
            .doc(req.id)
            .set(req.toMap());
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
        final updatedUser = _allUsers[userIdx].copyWith(
          assignedShift: req.requestedShift,
        );
        updateUser(updatedUser, bypassApproval: true);
      }

      if (_firestore != null) {
        try {
          await _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('shiftTimingRequests')
              .doc(req.id)
              .update({'status': 'approved'});
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
          await _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('shiftTimingRequests')
              .doc(req.id)
              .update({'status': 'rejected'});
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  // --- Users CRUD & Manager-to-Owner Approval Workflow ---
  void addNewUser(UserProfile newUser) {
    final isManagerActor =
        _currentUser != null && _currentUser!.role == UserRole.manager;
    final UserProfile userToSave = isManagerActor
        ? newUser.copyWith(
            approvalStatus: 'pending_approval',
            active: false,
            requestedBy: _currentUser!.name,
          )
        : newUser.copyWith(
            approvalStatus: 'approved',
            active: true,
            clearRequestedBy: true,
            clearPendingEditData: true,
          );

    _allUsers.removeWhere((u) => u.id == userToSave.id);
    _allUsers.add(userToSave);
    _savePersistedUsers();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('members')
            .doc(userToSave.id)
            .set(userToSave.toMap());
      } catch (_) {}
    }

    if (isManagerActor) {
      addNotification(
        title:
            'User Approval Requested: ${userToSave.name} (${userToSave.role.displayName})',
        subtitle:
            'Added by Manager ${_currentUser!.name} • Phone: ${userToSave.phoneNumber} • Tap People & Roles to approve',
        isWarning: true,
      );
    } else {
      addNotification(
        title:
            'New User Added: ${userToSave.name} (${userToSave.role.displayName})',
        subtitle:
            'Added by ${currentUser.name} • Phone: ${userToSave.phoneNumber}',
      );
    }
    notifyListeners();
  }

  void updateUser(UserProfile updatedUser, {bool bypassApproval = false}) {
    int idx = _allUsers.indexWhere((u) => u.id == updatedUser.id);
    if (idx != -1) {
      final existing = _allUsers[idx];
      final isManagerActor =
          !bypassApproval &&
          _currentUser != null &&
          _currentUser!.role == UserRole.manager &&
          updatedUser.id != _currentUser!.id;

      UserProfile finalUser;
      if (isManagerActor) {
        if (existing.isPendingApproval && !existing.hasPendingEdit) {
          // Editing an already-pending new user request
          finalUser = updatedUser.copyWith(
            approvalStatus: 'pending_approval',
            active: false,
            requestedBy: _currentUser!.name,
          );
        } else {
          // Editing an already-approved user: store proposed changes in pendingEditData until Owner approves
          final proposedMap = updatedUser
              .copyWith(
                approvalStatus: 'approved',
                clearPendingEditData: true,
                clearRequestedBy: true,
              )
              .toMap();
          finalUser = existing.copyWith(
            approvalStatus: 'pending_approval',
            requestedBy: _currentUser!.name,
            pendingEditData: proposedMap,
          );
        }
        addNotification(
          title: 'User Edit Approval Needed: ${updatedUser.name}',
          subtitle:
              'Edited by Manager ${_currentUser!.name} • Role: ${updatedUser.role.displayName}, Shift: ${updatedUser.assignedShift ?? "None"}',
          isWarning: true,
        );
      } else {
        finalUser = updatedUser.copyWith(
          approvalStatus: 'approved',
          clearPendingEditData: true,
          clearRequestedBy: true,
        );
      }

      _allUsers[idx] = finalUser;
      if (_currentUser?.id == finalUser.id) {
        _currentUser = finalUser;
      }
      _savePersistedUsers();
      _syncShiftsWithTimings();
      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('members')
              .doc(finalUser.id)
              .set(finalUser.toMap());
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  void approveUserRequest(String userId) {
    int idx = _allUsers.indexWhere((u) => u.id == userId);
    if (idx == -1) return;
    final existing = _allUsers[idx];
    UserProfile approved;
    if (existing.hasPendingEdit && existing.pendingEditData != null) {
      final parsed = UserProfile.fromMap(existing.pendingEditData!);
      approved = parsed.copyWith(
        id: existing.id,
        approvalStatus: 'approved',
        active: true,
        clearPendingEditData: true,
        clearRequestedBy: true,
        isOnline: existing.isOnline,
        appVersion: existing.appVersion.isNotEmpty
            ? existing.appVersion
            : parsed.appVersion,
        lastSeenAt: existing.lastSeenAt,
        lastLatitude: existing.lastLatitude,
        lastLongitude: existing.lastLongitude,
        lastDistanceMeters: existing.lastDistanceMeters,
        lastAccuracyMeters: existing.lastAccuracyMeters,
        isAtStation: existing.isAtStation,
        locationUpdatedAt: existing.locationUpdatedAt,
      );
    } else {
      approved = existing.copyWith(
        approvalStatus: 'approved',
        active: true,
        clearPendingEditData: true,
        clearRequestedBy: true,
      );
    }

    _allUsers[idx] = approved;
    if (_currentUser?.id == approved.id) {
      _currentUser = approved;
    }
    _savePersistedUsers();
    _syncShiftsWithTimings();
    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('members')
            .doc(approved.id)
            .set(approved.toMap());
      } catch (_) {}
    }

    addNotification(
      title: 'User Approved: ${approved.name} (${approved.role.displayName})',
      subtitle:
          'Approved by Owner ${currentUser.name} • Active for login & shift duty',
    );
    notifyListeners();
  }

  void rejectUserRequest(String userId) {
    int idx = _allUsers.indexWhere((u) => u.id == userId);
    if (idx == -1) return;
    final existing = _allUsers[idx];

    if (existing.hasPendingEdit) {
      // Revert pending edit and keep existing approved user
      final reverted = existing.copyWith(
        approvalStatus: 'approved',
        clearPendingEditData: true,
        clearRequestedBy: true,
      );
      _allUsers[idx] = reverted;
      _savePersistedUsers();
      if (_firestore != null) {
        try {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('members')
              .doc(reverted.id)
              .set(reverted.toMap());
        } catch (_) {}
      }
      addNotification(
        title: 'User Edit Rejected: ${existing.name}',
        subtitle: 'Manager edit request discarded by Owner ${currentUser.name}',
        isWarning: true,
      );
      notifyListeners();
    } else {
      // Was a brand-new unapproved user request -> remove
      deleteUser(userId);
      addNotification(
        title: 'New User Request Rejected: ${existing.name}',
        subtitle: 'Rejected and removed by Owner ${currentUser.name}',
        isWarning: true,
      );
    }
  }

  void deleteUser(String userId) {
    final deletedUser = _allUsers.where((u) => u.id == userId).firstOrNull;
    _allUsers.removeWhere((u) => u.id == userId);

    // Also remove any shifts and entries belonging to this deleted user
    final removedShifts = _allShifts
        .where(
          (s) =>
              s.staffId == userId ||
              (deletedUser != null &&
                  s.staffName.trim().toLowerCase() ==
                      deletedUser.name.trim().toLowerCase()),
        )
        .toList();
    _allShifts.removeWhere(
      (s) =>
          s.staffId == userId ||
          (deletedUser != null &&
              s.staffName.trim().toLowerCase() ==
                  deletedUser.name.trim().toLowerCase()),
    );

    List<TransactionEntry> removedEntries = [];
    if (deletedUser != null) {
      removedEntries = _entries
          .where(
            (e) =>
                e.createdBy.trim().toLowerCase() ==
                deletedUser.name.trim().toLowerCase(),
          )
          .toList();
      _entries.removeWhere(
        (e) =>
            e.createdBy.trim().toLowerCase() ==
            deletedUser.name.trim().toLowerCase(),
      );
    }

    _savePersistedUsers();
    _savePersistedShifts();
    _savePersistedEntries();

    if (_firestore != null) {
      try {
        _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('members')
            .doc(userId)
            .delete()
            .catchError((_) {});
        for (final s in removedShifts) {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('shifts')
              .doc(s.id)
              .delete()
              .catchError((_) {});
        }
        for (final e in removedEntries) {
          _firestore!
              .collection('stations')
              .doc('chatrai')
              .collection('entries')
              .doc(e.id)
              .delete()
              .catchError((_) {});
        }
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

      await _firestore!
          .collection('stations')
          .doc('chatrai')
          .collection('settings')
          .doc('general')
          .set(_settings.toMap());

      for (var u in _allUsers) {
        await _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('members')
            .doc(u.id)
            .set(u.toMap());
      }

      for (var p in _pumps) {
        await _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('pumps')
            .doc(p.id)
            .set(p.toMap());
      }

      for (var s in _allShifts) {
        await _firestore!
            .collection('stations')
            .doc('chatrai')
            .collection('shifts')
            .doc(s.id)
            .set(s.toMap());
      }

      return 'Successfully synchronized station records, members, pumps, shifts, and settings!';
    } catch (e) {
      return 'Error synchronizing cloud database: $e';
    }
  }

  /// Seeds a rich, realistic multi-user, multi-pump, multi-shift use-case dataset
  /// (Staff users, Pump 1 & Pump 2 nozzle readings, Receipt scans, Money entries with IST times,
  /// Credit Khata customers, and Shifts) both locally and to Cloud Firestore.
  Future<String> seedSampleUseCaseDataToFirestore() async {
    final now = DateTime.now();
    final todayStr = DateFormatter.formatDisplayDate(now);
    final printedDateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    DateTime todayAt(int hour, int minute) =>
        DateTime(now.year, now.month, now.day, hour, minute);

    final verLabel = currentPlatformVersionLabel;

    // 1. Realistic Station Team (3 Owners, 2 Managers, 3 Forecourt Staff)
    _allUsers = [
      UserProfile(
        id: 'owner_kalyan',
        name: 'Kalyan',
        email: 'kalyan@rfs.com',
        phoneNumber: '+91 98480 11111',
        role: UserRole.owner,
        preferredLanguage: 'en',
        isOnline: true,
        appVersion: verLabel,
        lastSeenAt: now,
        lastLatitude: 16.506210,
        lastLongitude: 80.648015,
        lastDistanceMeters: 4.2,
        lastAccuracyMeters: 8.5,
        isAtStation: true,
        locationUpdatedAt: now,
        lastLocationName: 'RFS (Chatrai), Eluru District',
      ),
      UserProfile(
        id: 'owner_ranjit',
        name: 'Ranjit',
        email: 'ranjit@rfs.com',
        phoneNumber: '+91 98480 22222',
        role: UserRole.owner,
        preferredLanguage: 'en',
        isOnline: false,
        appVersion: '${AppVersionService.displayVersion} (Android)',
        lastSeenAt: todayAt(8, 10),
      ),
      UserProfile(
        id: 'user_1791651818556',
        name: 'Abhilash',
        email: 'abhi@rfs.com',
        phoneNumber: '9492757943',
        role: UserRole.owner,
        preferredLanguage: 'te',
        isOnline: true,
        appVersion: '${AppVersionService.displayVersion} (Android)',
        lastSeenAt: todayAt(8, 12),
      ),
      UserProfile(
        id: 'mgr_ramesh',
        name: 'Ramesh Babu',
        email: 'ramesh@rfs.com',
        phoneNumber: '+91 94401 44556',
        role: UserRole.manager,
        assignedShift: 'Morning',
        preferredLanguage: 'te',
        isOnline: true,
        appVersion: '${AppVersionService.displayVersion} (Android)',
        lastSeenAt: todayAt(8, 30),
        lastLatitude: 16.506225,
        lastLongitude: 80.648022,
        lastDistanceMeters: 6.8,
        lastAccuracyMeters: 9.2,
        isAtStation: true,
        locationUpdatedAt: todayAt(8, 30),
        lastLocationName: 'RFS Forecourt Office, Chatrai Main Road',
      ),
      UserProfile(
        id: 'mgr_venkat',
        name: 'Venkat Rao',
        email: 'venkat@rfs.com',
        phoneNumber: '+91 94401 77889',
        role: UserRole.manager,
        assignedShift: 'Evening',
        preferredLanguage: 'te',
        isOnline: false,
        appVersion: '${AppVersionService.displayVersion} (Android)',
        lastSeenAt: todayAt(7, 45),
      ),
      UserProfile(
        id: 'user_1791642830525',
        name: 'Srinivas',
        email: 'srinivas@rfs.com',
        phoneNumber: '9533677647',
        role: UserRole.shiftStaff,
        assignedShift: 'Morning',
        preferredLanguage: 'te',
        isOnline: true,
        appVersion: '${AppVersionService.displayVersion} (Android)',
        lastSeenAt: todayAt(8, 42),
        lastLatitude: 16.506195,
        lastLongitude: 80.647995,
        lastDistanceMeters: 5.1,
        lastAccuracyMeters: 7.4,
        isAtStation: true,
        locationUpdatedAt: todayAt(8, 42),
        lastLocationName: 'Pump 1 Island, RFS (Chatrai)',
      ),
      UserProfile(
        id: 'staff_anjaneyulu',
        name: 'Anjaneyulu',
        email: 'anjaneyulu@rfs.com',
        phoneNumber: '9177255667',
        role: UserRole.shiftStaff,
        assignedShift: 'Morning',
        preferredLanguage: 'te',
        isOnline: true,
        appVersion: '${AppVersionService.displayVersion} (Android)',
        lastSeenAt: todayAt(8, 45),
        lastLatitude: 16.506240,
        lastLongitude: 80.648035,
        lastDistanceMeters: 7.9,
        lastAccuracyMeters: 8.1,
        isAtStation: true,
        locationUpdatedAt: todayAt(8, 45),
        lastLocationName: 'Pump 2 Island, RFS (Chatrai)',
      ),
      UserProfile(
        id: 'staff_prabhakar',
        name: 'Prabhakar',
        email: 'prabhakar@rfs.com',
        phoneNumber: '9177288990',
        role: UserRole.shiftStaff,
        assignedShift: 'Evening',
        preferredLanguage: 'te',
        isOnline: false,
        appVersion: '${AppVersionService.displayVersion} (Android)',
        lastSeenAt: todayAt(7, 15),
      ),
    ];

    if (_currentUser != null) {
      final idx = _allUsers.indexWhere((u) => u.id == _currentUser!.id);
      if (idx != -1) {
        _currentUser = _allUsers[idx];
      }
    }

    // 2. Two Active Pumps with Opening & Closing Totaliser Readings
    // Pump 1:
    //   Nozzle 1 (Petrol): Opening 168,676.720 L -> Closing 169,531.720 L (Gross 855.00 L, Test 5.00 L, Net 850.00 L @ ₹117.52 = ₹99,892.00)
    //   Nozzle 2 (Diesel): Opening 273,287.210 L -> Closing 274,492.210 L (Gross 1,205.00 L, Test 5.00 L, Net 1,200.00 L @ ₹105.21 = ₹1,26,252.00)
    // Pump 2:
    //   Nozzle 1 (Petrol): Opening 83,398.950 L -> Closing 84,043.950 L (Gross 645.00 L, Test 5.00 L, Net 640.00 L @ ₹117.52 = ₹75,212.80)
    //   Nozzle 2 (Diesel): Opening 121,958.960 L -> Closing 122,913.960 L (Gross 955.00 L, Test 5.00 L, Net 950.00 L @ ₹105.21 = ₹99,949.50)
    // Total Net Fuel Sales Today = ₹4,01,306.30 (40130630 paise)
    const int pRate = 11752;
    const int dRate = 10521;
    _pumps = const [
      Pump(
        id: 'pump_1',
        name: 'Pump 1',
        serialNumber: '202501001272',
        referenceReceiptAsset: 'assets/images/media_1791634198035.png',
        nozzles: [
          Nozzle(
            id: 'p1_n1',
            pumpId: 'pump_1',
            nozzleNumber: 1,
            fuelType: 'Petrol',
            ratePaisePerLitre: pRate,
            currentTotaliserMl: 169531720,
            previousAcceptedReadingMl: 168676720,
          ),
          Nozzle(
            id: 'p1_n2',
            pumpId: 'pump_1',
            nozzleNumber: 2,
            fuelType: 'Diesel',
            ratePaisePerLitre: dRate,
            currentTotaliserMl: 274492210,
            previousAcceptedReadingMl: 273287210,
          ),
        ],
      ),
      Pump(
        id: 'pump_2',
        name: 'Pump 2',
        serialNumber: '202501001289',
        referenceReceiptAsset: 'assets/images/media_1791634198035.png',
        nozzles: [
          Nozzle(
            id: 'p2_n1',
            pumpId: 'pump_2',
            nozzleNumber: 1,
            fuelType: 'Petrol',
            ratePaisePerLitre: pRate,
            currentTotaliserMl: 84043950,
            previousAcceptedReadingMl: 83398950,
          ),
          Nozzle(
            id: 'p2_n2',
            pumpId: 'pump_2',
            nozzleNumber: 2,
            fuelType: 'Diesel',
            ratePaisePerLitre: dRate,
            currentTotaliserMl: 122913960,
            previousAcceptedReadingMl: 121958960,
          ),
        ],
      ),
    ];

    // 3. Approved Opening & Closing Receipt Scans for Today (so Date-Filtered Owner Reports compute exact sales)
    _receipts = [
      ReceiptScan(
        id: 'scan_p1_open',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: printedDateStr,
        printedTime: '06:02:14',
        nozzleCumVolumeMl: const {1: 168676720, 2: 273287210},
        nozzleRatesPaisePerLitre: const {1: pRate, 2: dRate},
        imagePath: 'sample_pump1_opening.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Opening totaliser reading verified',
        capturedBy: 'Srinivas',
        capturedAt: todayAt(6, 2),
        scanLatitude: 16.506195,
        scanLongitude: 80.647995,
        scanLocationName: 'Pump 1 Island, RFS (Chatrai)',
        reviewStatus: 'approved',
      ),
      ReceiptScan(
        id: 'scan_p1_close',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: printedDateStr,
        printedTime: '08:38:45',
        nozzleCumVolumeMl: const {1: 169531720, 2: 274492210},
        nozzleRatesPaisePerLitre: const {1: pRate, 2: dRate},
        imagePath: 'sample_pump1_closing.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage:
            'Closing totaliser reading verified (855 L Petrol, 1,205 L Diesel)',
        capturedBy: 'Srinivas',
        capturedAt: todayAt(8, 38),
        scanLatitude: 16.506195,
        scanLongitude: 80.647995,
        scanLocationName: 'Pump 1 Island, RFS (Chatrai)',
        reviewStatus: 'approved',
      ),
      ReceiptScan(
        id: 'scan_p2_open',
        pumpSerialNumber: '202501001289',
        fpId: '2',
        printedDate: printedDateStr,
        printedTime: '06:05:10',
        nozzleCumVolumeMl: const {1: 83398950, 2: 121958960},
        nozzleRatesPaisePerLitre: const {1: pRate, 2: dRate},
        imagePath: 'sample_pump2_opening.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Opening totaliser reading verified',
        capturedBy: 'Anjaneyulu',
        capturedAt: todayAt(6, 5),
        scanLatitude: 16.506240,
        scanLongitude: 80.648035,
        scanLocationName: 'Pump 2 Island, RFS (Chatrai)',
        reviewStatus: 'approved',
      ),
      ReceiptScan(
        id: 'scan_p2_close',
        pumpSerialNumber: '202501001289',
        fpId: '2',
        printedDate: printedDateStr,
        printedTime: '08:41:20',
        nozzleCumVolumeMl: const {1: 84043950, 2: 122913960},
        nozzleRatesPaisePerLitre: const {1: pRate, 2: dRate},
        imagePath: 'sample_pump2_closing.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage:
            'Closing totaliser reading verified (645 L Petrol, 955 L Diesel)',
        capturedBy: 'Anjaneyulu',
        capturedAt: todayAt(8, 41),
        scanLatitude: 16.506240,
        scanLongitude: 80.648035,
        scanLocationName: 'Pump 2 Island, RFS (Chatrai)',
        reviewStatus: 'approved',
      ),
    ];

    // 4. 13 Realistic Money Entries Across Staff & Categories with Explicit IST Times
    // Total Received = PhonePe (₹1,60,650.50) + Card (₹68,800.00) + Credit (₹40,000.00) + Cash (₹1,31,855.80) = ₹4,01,306.30
    // Paid Out = Expense (₹1,650.00) + To Owner (₹1,10,000.00) = ₹1,11,650.00
    // Cash Remaining on Forecourt = ₹1,31,855.80 - ₹1,11,650.00 = ₹20,205.80
    _entries = [
      TransactionEntry(
        id: 'uc_entry_13',
        shiftId: 'shift_morning',
        category: EntryCategory.toOwner,
        direction: EntryDirection.paidOut,
        amountPaise: 4000000, // ₹40,000.00
        reference: 'Pump 2 cash handover to Owner (Kalyan)',
        createdAt: todayAt(8, 45),
        timeString: '08:45 AM',
        createdBy: 'Anjaneyulu',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_12',
        shiftId: 'shift_morning',
        category: EntryCategory.toOwner,
        direction: EntryDirection.paidOut,
        amountPaise: 7000000, // ₹70,000.00
        reference: 'Pump 1 morning cash handover to Owner (Kalyan)',
        createdAt: todayAt(8, 40),
        timeString: '08:40 AM',
        createdBy: 'Srinivas',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_11',
        shiftId: 'shift_morning',
        category: EntryCategory.cash,
        direction: EntryDirection.received,
        amountPaise: 4611200, // ₹46,112.00
        reference: 'Pump 2 forecourt cash collection',
        createdAt: todayAt(8, 35),
        timeString: '08:35 AM',
        createdBy: 'Anjaneyulu',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_10',
        shiftId: 'shift_morning',
        category: EntryCategory.cash,
        direction: EntryDirection.received,
        amountPaise: 8574380, // ₹85,743.80
        reference: 'Pump 1 forecourt cash collection',
        createdAt: todayAt(8, 30),
        timeString: '08:30 AM',
        createdBy: 'Srinivas',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_09',
        shiftId: 'shift_morning',
        category: EntryCategory.card,
        direction: EntryDirection.received,
        amountPaise: 2630000, // ₹26,300.00
        reference: 'HDFC POS Terminal #2 batch settlement',
        createdAt: todayAt(8, 20),
        timeString: '08:20 AM',
        createdBy: 'Anjaneyulu',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_08',
        shiftId: 'shift_morning',
        category: EntryCategory.credit,
        direction: EntryDirection.received,
        amountPaise: 1850000, // ₹18,500.00
        reference: 'Sri Rama Earthmovers (JCB & Tipper Fleet)',
        createdAt: todayAt(8, 10),
        timeString: '08:10 AM',
        createdBy: 'Anjaneyulu',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_07',
        shiftId: 'shift_morning',
        category: EntryCategory.card,
        direction: EntryDirection.received,
        amountPaise: 4250000, // ₹42,500.00
        reference: 'SBI POS Terminal #1 fleet card swipes',
        createdAt: todayAt(8, 5),
        timeString: '08:05 AM',
        createdBy: 'Srinivas',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_06',
        shiftId: 'shift_morning',
        category: EntryCategory.expense,
        direction: EntryDirection.paidOut,
        amountPaise: 120000, // ₹1,200.00
        reference: 'Generator distilled water & stabilizer fuse',
        createdAt: todayAt(8, 0),
        timeString: '08:00 AM',
        createdBy: 'Anjaneyulu',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_05',
        shiftId: 'shift_morning',
        category: EntryCategory.credit,
        direction: EntryDirection.received,
        amountPaise: 1200000, // ₹12,000.00
        reference: 'Maruthi Travels (Bus AP39 TK 4599)',
        createdAt: todayAt(7, 50),
        timeString: '07:50 AM',
        createdBy: 'Srinivas',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_04',
        shiftId: 'shift_morning',
        category: EntryCategory.phonePe,
        direction: EntryDirection.received,
        amountPaise: 6825050, // ₹68,250.50
        phonePeNumber: '9440155667',
        reference: 'Pump 2 QR Standee #2 UPI collections',
        createdAt: todayAt(7, 42),
        timeString: '07:42 AM',
        createdBy: 'Anjaneyulu',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_03',
        shiftId: 'shift_morning',
        category: EntryCategory.expense,
        direction: EntryDirection.paidOut,
        amountPaise: 45000, // ₹450.00
        reference: 'Staff tea, tiffin & drinking water cans (Food)',
        createdAt: todayAt(7, 30),
        timeString: '07:30 AM',
        createdBy: 'Srinivas',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_02',
        shiftId: 'shift_morning',
        category: EntryCategory.phonePe,
        direction: EntryDirection.received,
        amountPaise: 9240000, // ₹92,400.00
        phonePeNumber: '9848011111',
        reference: 'Pump 1 QR Standee #1 UPI collections',
        createdAt: todayAt(7, 15),
        timeString: '07:15 AM',
        createdBy: 'Srinivas',
        status: 'Approved',
      ),
      TransactionEntry(
        id: 'uc_entry_01',
        shiftId: 'shift_evening',
        category: EntryCategory.credit,
        direction: EntryDirection.received,
        amountPaise: 950000, // ₹9,500.00
        reference: 'Lakshmi Narasimha Tractors (Chatrai Agri)',
        createdAt: todayAt(6, 45),
        timeString: '06:45 AM',
        createdBy: 'Prabhakar',
        status: 'Approved',
      ),
    ];

    // 5. Credit Khata Customers (matching the 3 Credit sales = ₹40,000.00 total pending)
    _creditCustomers = [
      CreditCustomer(
        id: 'cust_maruthi',
        name: 'Maruthi Travels',
        subtitle: 'Bus AP39 TK 4599 • Monthly Diesel Account',
        pendingAmountPaise: 1200000, // ₹12,000.00
        lastCreditDate: todayAt(7, 50),
        payments: [
          CreditPayment(
            id: 'kp_1',
            amountPaise: 1500000,
            mode: 'PhonePe',
            date: now.subtract(const Duration(days: 2)),
            note: 'Previous week settlement',
          ),
        ],
      ),
      CreditCustomer(
        id: 'cust_srirama',
        name: 'Sri Rama Earthmovers',
        subtitle: 'JCB & Tipper Fleet • Chatrai Quarry Project',
        pendingAmountPaise: 1850000, // ₹18,500.00
        lastCreditDate: todayAt(8, 10),
        payments: [
          CreditPayment(
            id: 'kp_2',
            amountPaise: 2500000,
            mode: 'Cash',
            date: now.subtract(const Duration(days: 3)),
            note: 'Cleared by site supervisor',
          ),
        ],
      ),
      CreditCustomer(
        id: 'cust_lakshmi',
        name: 'Lakshmi Narasimha Tractors',
        subtitle: 'Chatrai Agri Harvest Fleet',
        pendingAmountPaise: 950000, // ₹9,500.00
        lastCreditDate: todayAt(6, 45),
        payments: const [],
      ),
    ];

    // 6. Active & Submitted Shifts for Today
    _allShifts = [
      Shift(
        id: 'shift_morning',
        shiftName: 'Morning',
        businessDate: todayStr,
        staffId: 'user_1791642830525',
        staffName: 'Srinivas',
        pumpName: 'Pump 1',
        status: ShiftStatus.inProgress,
        timeRange: '06:00 AM - 02:00 PM',
        openingReadingsMl: const {1: 168676720, 2: 273287210},
        closingReadingsMl: const {1: 169531720, 2: 274492210},
        testVolumesMl: const {1: 5000, 2: 5000},
        cashHandoverPaise: 7000000, // ₹70,000.00 handed over by Srinivas
        handoverReceiver: 'Kalyan',
        handoverTime: todayAt(8, 40),
        note:
            'Pump 1 morning readings verified and ₹70,000.00 cash handed over to Kalyan.',
      ),
      Shift(
        id: 'shift_evening',
        shiftName: 'Evening',
        businessDate: todayStr,
        staffId: 'staff_anjaneyulu',
        staffName: 'Anjaneyulu',
        pumpName: 'Pump 2',
        status: ShiftStatus.needsReview,
        timeRange: '02:00 PM - 10:00 PM',
        openingReadingsMl: const {1: 83398950, 2: 121958960},
        closingReadingsMl: const {1: 84043950, 2: 122913960},
        testVolumesMl: const {1: 5000, 2: 5000},
        cashHandoverPaise: 4000000, // ₹40,000.00 handed over by Anjaneyulu
        handoverReceiver: 'Kalyan',
        handoverTime: todayAt(8, 45),
        note: 'Pump 2 closing slip scanned and submitted for Owner approval.',
      ),
    ];

    // 7. Hierarchical Cash Handover Workflow Records
    _cashHandovers = [
      CashHandoverRecord(
        id: 'uc_handover_02',
        shiftId: 'shift_morning',
        shiftName: 'Morning',
        businessDate: todayStr,
        fromUserId: 'staff_anjaneyulu',
        fromUserName: 'Anjaneyulu',
        fromUserRole: 'shiftStaff',
        toUserId: 'owner_kalyan',
        toUserName: 'Kalyan',
        toUserRole: 'owner',
        amountPaise: 4000000, // ₹40,000.00
        status: CashHandoverStatus.pending,
        createdAt: todayAt(8, 45),
        timeString: '08:45 AM',
        note: 'Pump 2 cash handover to Kalyan',
        linkedEntryId: 'uc_entry_13',
      ),
      CashHandoverRecord(
        id: 'uc_handover_01',
        shiftId: 'shift_morning',
        shiftName: 'Morning',
        businessDate: todayStr,
        fromUserId: 'user_1791642830525',
        fromUserName: 'Srinivas',
        fromUserRole: 'shiftStaff',
        toUserId: 'owner_kalyan',
        toUserName: 'Kalyan',
        toUserRole: 'owner',
        amountPaise: 7000000, // ₹70,000.00
        status: CashHandoverStatus.accepted,
        createdAt: todayAt(8, 40),
        timeString: '08:40 AM',
        respondedAt: todayAt(8, 42),
        note: 'Pump 1 morning cash handover to Kalyan',
        linkedEntryId: 'uc_entry_12',
      ),
    ];

    // Ensure Morning, Evening, and Night shifts are configured and deletedEntryIds is empty
    _settings = _settings.copyWith(
      shiftTimings: const {
        'Morning': '06:00 AM - 02:00 PM',
        'Evening': '02:00 PM - 10:00 PM',
        'Night': '10:00 PM - 06:00 AM',
      },
      deletedEntryIds: const [],
    );

    // Persist locally
    await _savePersistedUsers();
    await _savePersistedPumps();
    await _savePersistedReceipts();
    await _savePersistedEntries();
    await _savePersistedCreditCustomers();
    await _savePersistedShifts();
    await _savePersistedCashHandovers();
    await _savePersistedSettings();
    notifyListeners();

    // Sync to Cloud Firestore if connected
    if (_firestore != null) {
      try {
        final stationRef = _firestore!.collection('stations').doc('chatrai');
        await stationRef
            .collection('settings')
            .doc('general')
            .set(_settings.toMap());
        for (final u in _allUsers) {
          await stationRef.collection('members').doc(u.id).set(u.toMap());
        }
        for (final p in _pumps) {
          await stationRef.collection('pumps').doc(p.id).set(p.toMap());
        }
        for (final r in _receipts) {
          await stationRef.collection('scanAttempts').doc(r.id).set(r.toMap());
        }
        for (final e in _entries) {
          await stationRef.collection('entries').doc(e.id).set(e.toMap());
        }
        for (final c in _creditCustomers) {
          await stationRef
              .collection('creditCustomers')
              .doc(c.id)
              .set(c.toMap());
        }
        for (final s in _allShifts) {
          await stationRef.collection('shifts').doc(s.id).set(s.toMap());
        }
        for (final h in _cashHandovers) {
          await stationRef.collection('cashHandovers').doc(h.id).set(h.toMap());
        }
      } catch (e) {
        return 'Loaded sample use-case data locally (Cloud sync warning: $e)';
      }
    }

    return 'Loaded sample use-case data: 8 Users, 2 Pumps (3,640 L sold = ₹4,01,306.30), 13 Money Entries, 3 Credit Khata accounts (₹40,000.00), and 2 Shifts!';
  }

  bool _purgingOperationalData = false;

  Future<String> clearAllFirestoreCollections() async {
    if (_purgingOperationalData) return 'Purge already in progress.';
    _purgingOperationalData = true;
    try {
      final purgedIds = <String>{
        ..._settings.deletedEntryIds,
        ..._entries.map((e) => e.id.trim()).where((id) => id.isNotEmpty),
        'entry_1791680675746',
      };
      _settings = _settings.copyWith(deletedEntryIds: purgedIds.toList());

      _purgedHandoverIds.addAll(_cashHandovers.map((h) => h.id));
      final purgePrefs = await SharedPreferences.getInstance();
      await purgePrefs.setStringList(_prefPurgedHandoverIds, _purgedHandoverIds.toList());

      // 1. Reset local operational records immediately
      _entries = [];
      _receipts = [];
      _timingRequests = [];
      _creditCustomers = [];
      _notifications = [];
      _allShifts = [];
      _cashHandovers = [];

      // 2. Reset pump nozzle current readings to baseline opening readings so today's sales = 0.0 L
      _pumps = _pumps.map((pump) {
        final resetNozzles = pump.nozzles.map((n) {
          return n.copyWith(currentTotaliserMl: n.previousAcceptedReadingMl);
        }).toList();
        return pump.copyWith(nozzles: resetNozzles);
      }).toList();

      // 3. Re-activate shift only if the currently logged-in user is assigned to a shift
      if (_currentUser != null && _currentUser!.assignedShift != null) {
        _activateShiftForLoggedInUser(_currentUser!);
      }

      // 4. Persist clean state to SharedPreferences
      await _savePersistedSettings();
      await _savePersistedEntries();
      await _savePersistedReceipts();
      await _savePersistedCreditCustomers();
      await _savePersistedNotifications();
      await _savePersistedPumps();
      await _savePersistedShifts();
      await _savePersistedCashHandovers();
      notifyListeners();

      if (_firestore == null) {
        return 'Local operational records, dispenser readings, credit khata, and shift handovers reset to zero.';
      }

      try {
        final stationRef = _firestore!.collection('stations').doc('chatrai');

        final collectionsToPurge = [
          'entries',
          'scanAttempts',
          'receipts',
          'cashHandovers',
          'shiftTimingRequests',
          'creditCustomers',
          'notifications',
          'shifts',
        ];

        for (final col in collectionsToPurge) {
          while (true) {
            final snap = await stationRef.collection(col).limit(200).get(const GetOptions(source: Source.server));
            if (snap.docs.isEmpty) break;
            final batch = _firestore!.batch();
            for (final doc in snap.docs) {
              if (col == 'entries') purgedIds.add(doc.id.trim());
              if (col == 'cashHandovers') _purgedHandoverIds.add(doc.id);
              batch.delete(doc.reference);
            }
            await batch.commit();
            if (col == 'cashHandovers') {
              await purgePrefs.setStringList(_prefPurgedHandoverIds, _purgedHandoverIds.toList());
            }
          }
        }

        _settings = _settings.copyWith(deletedEntryIds: purgedIds.toList());
        await _savePersistedSettings();
        await stationRef
            .collection('settings')
            .doc('general')
            .set(_settings.toMap());

        // Sync reset pumps to Firestore
        for (var p in _pumps) {
          await stationRef.collection('pumps').doc(p.id).set(p.toMap());
        }

        // Write active shift only if one is currently active
        for (var s in _allShifts) {
          await stationRef.collection('shifts').doc(s.id).set(s.toMap());
        }

        notifyListeners();
        return 'All operational records, dispenser readings, credit khata, notifications, and shifts purged from local & cloud database.';
      } catch (e) {
        return 'Local records reset. CLOUD PURGE INCOMPLETE: deletion failed (quota, connectivity, or permission error). Cloud records remain; retry purge after the error is resolved. Details: $e';
      }
    } finally {
      _purgingOperationalData = false;
    }
  }

  bool isReceiptOnDate(ReceiptScan scan, DateTime date) {
    // Printed business date owns the record; upload time must not double-count
    // yesterday's receipt in today's analytics.
    final parts = scan.printedDate.split(RegExp(r'[/.-]'));
    if (parts.length >= 3) {
      final yearFirst = parts[0].length == 4;
      final d = int.tryParse(parts[yearFirst ? 2 : 0]);
      final m = int.tryParse(parts[1]);
      var y = int.tryParse(parts[yearFirst ? 0 : 2]);
      if (y != null && y < 100) y += 2000;
      if (d != null && m != null && y != null) {
        final parsed = DateTime.utc(y, m, d);
        if (parsed.day == d && parsed.month == m) {
          return d == date.day && m == date.month && y == date.year;
        }
      }
    }
    final captured = DateFormatter.toIST(scan.capturedAt);
    return captured.year == date.year &&
        captured.month == date.month &&
        captured.day == date.day;
  }

  /// Calculates authoritative dispenser fuel volumes, mandatory 5L test deductions,
  /// billable litres sold, expected revenue, and financial settlement for a specific date.
  StationDayCalculationResult getDayCalculation(DateTime date) {
    final nowIst = DateFormatter.toIST(DateTime.now());
    final bool isToday =
        date.year == nowIst.year &&
        date.month == nowIst.month &&
        date.day == nowIst.day;

    final dayReceipts = _receipts
        .where((r) => isReceiptOnDate(r, date))
        .toList();
    // Chronological order (earliest first, latest last)
    dayReceipts.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    final List<PumpDayCalculationResult> pumpResults = [];
    final List<NozzleCalculationResult> allNozzleResults = [];

    double totalStationGross = 0;
    double totalStationTest = 0;
    double totalStationNet = 0;
    double totalStationMs = 0;
    double totalStationHsd = 0;
    int totalStationFuelSalesPaise = 0;

    for (var pump in _pumps) {
      final pumpReceipts = dayReceipts.where((r) {
        return r.pumpSerialNumber == pump.serialNumber ||
            r.fpId == pump.id.replaceAll('pump_', '') ||
            pump.name.toLowerCase().contains('pump ${r.fpId}'.toLowerCase());
      }).toList();

      final List<NozzleCalculationResult> pumpNozzles = [];
      double pumpGross = 0;
      double pumpTest = 0;
      double pumpNet = 0;
      double pumpMs = 0;
      double pumpHsd = 0;
      int pumpFuelSalesPaise = 0;
      bool pumpHasReadings = false;

      // Staff assigned or who captured
      String staffName = '';
      if (pumpReceipts.isNotEmpty) {
        staffName = pumpReceipts.last.capturedBy;
      } else {
        final shiftMatches = visibleShifts
            .where(
              (s) =>
                  s.pumpName == pump.name ||
                  s.pumpName.contains(pump.id.replaceAll('pump_', '')),
            )
            .toList();
        if (shiftMatches.isNotEmpty) {
          staffName = shiftMatches.first.staffName;
        } else if (visibleShifts.isNotEmpty) {
          staffName = visibleShifts.first.staffName;
        } else {
          staffName = 'Unassigned';
        }
      }

      for (var nozzle in pump.nozzles) {
        final nozzleScans = pumpReceipts
            .where((r) => r.nozzleCumVolumeMl.containsKey(nozzle.nozzleNumber))
            .toList();
        nozzleScans.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

        int openMl = 0;
        int closeMl = 0;
        bool nozzleHasReadings = false;

        // Baseline rate entering this day's calculation
        int initialRate = nozzle.ratePaisePerLitre;
        final priorScansWithRate = _receipts
            .where(
              (r) =>
                  r.capturedAt.isBefore(
                    nozzleScans.isNotEmpty
                        ? nozzleScans.first.capturedAt
                        : (isToday ? DateTime.now() : date),
                  ) &&
                  r.nozzleRatesPaisePerLitre != null &&
                  (r.nozzleRatesPaisePerLitre![nozzle.nozzleNumber] ?? 0) > 0 &&
                  (r.pumpSerialNumber == pump.serialNumber ||
                      r.fpId == pump.id.replaceAll('pump_', '') ||
                      pump.name.toLowerCase().contains(
                        'pump ${r.fpId}'.toLowerCase(),
                      )),
            )
            .toList();
        if (priorScansWithRate.isNotEmpty) {
          priorScansWithRate.sort(
            (a, b) => b.capturedAt.compareTo(a.capturedAt),
          );
          initialRate = priorScansWithRate
              .first
              .nozzleRatesPaisePerLitre![nozzle.nozzleNumber]!;
        } else if (nozzleScans.isNotEmpty &&
            (nozzleScans.first.nozzleRatesPaisePerLitre?[nozzle.nozzleNumber] ??
                    0) >
                0) {
          initialRate =
              nozzleScans.first.nozzleRatesPaisePerLitre![nozzle.nozzleNumber]!;
        }

        final List<
          ({
            int fromMl,
            int toMl,
            int ratePaisePerLitre,
            DateTime? startTime,
            DateTime? endTime,
          })
        >
        segments = [];

        if (nozzleScans.length >= 2) {
          // Multiple scans on that date: first recording of the day and ending recording of the day!
          openMl = nozzleScans.first.nozzleCumVolumeMl[nozzle.nozzleNumber]!;
          closeMl = nozzleScans.last.nozzleCumVolumeMl[nozzle.nozzleNumber]!;
          nozzleHasReadings = true;

          int activeRate =
              (nozzleScans.first.nozzleRatesPaisePerLitre?[nozzle
                          .nozzleNumber] ??
                      0) >
                  0
              ? nozzleScans.first.nozzleRatesPaisePerLitre![nozzle
                    .nozzleNumber]!
              : initialRate;
          int curReading = openMl;
          DateTime curTime = nozzleScans.first.capturedAt;

          for (int i = 1; i < nozzleScans.length; i++) {
            final nextScan = nozzleScans[i];
            final nextReading =
                nextScan.nozzleCumVolumeMl[nozzle.nozzleNumber]!;
            final nextRate =
                nextScan.nozzleRatesPaisePerLitre?[nozzle.nozzleNumber];

            if (nextReading > curReading) {
              segments.add((
                fromMl: curReading,
                toMl: nextReading,
                ratePaisePerLitre: activeRate,
                startTime: curTime,
                endTime: nextScan.capturedAt,
              ));
              curReading = nextReading;
              curTime = nextScan.capturedAt;
            }

            if (nextRate != null && nextRate > 0) {
              activeRate = nextRate;
            }
          }
        } else if (nozzleScans.length == 1) {
          // 1 scan on that date: closing is this scan, opening is nozzle.previousAcceptedReadingMl (or last scan prior to this date)
          closeMl = nozzleScans.first.nozzleCumVolumeMl[nozzle.nozzleNumber]!;
          final priorScans = _receipts
              .where(
                (r) =>
                    r.capturedAt.isBefore(nozzleScans.first.capturedAt) &&
                    r.nozzleCumVolumeMl.containsKey(nozzle.nozzleNumber) &&
                    (r.pumpSerialNumber == pump.serialNumber ||
                        r.fpId == pump.id.replaceAll('pump_', '') ||
                        pump.name.toLowerCase().contains(
                          'pump ${r.fpId}'.toLowerCase(),
                        )),
              )
              .toList();
          if (priorScans.isNotEmpty) {
            priorScans.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
            openMl = priorScans.first.nozzleCumVolumeMl[nozzle.nozzleNumber]!;
          } else {
            openMl = nozzle.previousAcceptedReadingMl;
          }
          if (closeMl < openMl) {
            openMl = closeMl;
          }
          nozzleHasReadings = true;

          int scanRate =
              (nozzleScans.first.nozzleRatesPaisePerLitre?[nozzle
                          .nozzleNumber] ??
                      0) >
                  0
              ? nozzleScans.first.nozzleRatesPaisePerLitre![nozzle
                    .nozzleNumber]!
              : initialRate;

          if (closeMl > openMl) {
            segments.add((
              fromMl: openMl,
              toMl: closeMl,
              ratePaisePerLitre: scanRate,
              startTime: nozzleScans.first.capturedAt,
              endTime: nozzleScans.first.capturedAt,
            ));
          }
        } else {
          // No scans specifically for this date
          if (isToday) {
            openMl = nozzle.previousAcceptedReadingMl;
            closeMl = nozzle.currentTotaliserMl;
            nozzleHasReadings = closeMl > openMl;
            if (closeMl > openMl) {
              segments.add((
                fromMl: openMl,
                toMl: closeMl,
                ratePaisePerLitre: nozzle.ratePaisePerLitre,
                startTime: null,
                endTime: null,
              ));
            }
          } else {
            openMl = 0;
            closeMl = 0;
            nozzleHasReadings = false;
          }
        }

        if (nozzleHasReadings) {
          pumpHasReadings = true;
        }

        final int grossMl = closeMl >= openMl ? (closeMl - openMl) : 0;
        // Daily mandatory 5L (5000 mL) deduction
        final int testMl = grossMl >= 5000 ? 5000 : grossMl;

        // Consolidate adjacent segments with identical rate
        final List<
          ({
            int fromMl,
            int toMl,
            int ratePaisePerLitre,
            DateTime? startTime,
            DateTime? endTime,
          })
        >
        consolidatedSegments = [];
        for (var s in segments) {
          if (consolidatedSegments.isNotEmpty &&
              consolidatedSegments.last.ratePaisePerLitre ==
                  s.ratePaisePerLitre) {
            final prev = consolidatedSegments.removeLast();
            consolidatedSegments.add((
              fromMl: prev.fromMl,
              toMl: s.toMl,
              ratePaisePerLitre: prev.ratePaisePerLitre,
              startTime: prev.startTime,
              endTime: s.endTime,
            ));
          } else {
            consolidatedSegments.add(s);
          }
        }

        final nRes = ReconciliationService.calculateMultiSegmentNozzle(
          nozzleNumber: nozzle.nozzleNumber,
          fuelType: nozzle.fuelType,
          openingReadingMl: openMl,
          closingReadingMl: closeMl,
          totalTestVolumeMl: testMl,
          rawSegments: consolidatedSegments,
          pumpId: pump.id,
          pumpName: pump.name,
        );

        pumpNozzles.add(nRes);
        allNozzleResults.add(nRes);

        final gL = nRes.grossLitres;
        final tL = nRes.testLitres;
        final nL = nRes.billableLitres;

        pumpGross += gL;
        pumpTest += tL;
        pumpNet += nL;
        if (nozzle.fuelType.toLowerCase().contains('petrol') ||
            nozzle.fuelType.toLowerCase().contains('ms')) {
          pumpMs += nL;
        } else {
          pumpHsd += nL;
        }
        pumpFuelSalesPaise += nRes.fuelSalesPaise;
      }

      totalStationGross += pumpGross;
      totalStationTest += pumpTest;
      totalStationNet += pumpNet;
      totalStationMs += pumpMs;
      totalStationHsd += pumpHsd;
      totalStationFuelSalesPaise += pumpFuelSalesPaise;

      pumpResults.add(
        PumpDayCalculationResult(
          pump: pump,
          staffName: staffName,
          nozzleResults: pumpNozzles,
          totalFuelSalesPaise: pumpFuelSalesPaise,
          totalGrossLitres: pumpGross,
          totalTestLitres: pumpTest,
          totalNetLitres: pumpNet,
          msLitres: pumpMs,
          hsdLitres: pumpHsd,
          hasReadings: pumpHasReadings,
        ),
      );
    }

    // Filter transaction entries strictly for this date
    final dayEntries = _entries.where((e) {
      final created = DateFormatter.toIST(e.createdAt);
      return created.year == date.year &&
          created.month == date.month &&
          created.day == date.day;
    }).toList();

    int cash = 0;
    int phonePe = 0;
    int card = 0;
    int credit = 0;
    int toOwner = 0;
    int food = 0;
    int otherDebits = 0;

    for (var e in dayEntries) {
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
            final ref = (e.reference ?? '').toLowerCase();
            if (ref.contains('food') ||
                ref.contains('curries') ||
                ref.contains('tea')) {
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

    final int recordedSales = cash + phonePe + card + credit;
    final bool hasData =
        pumpResults.any((p) => p.hasReadings) || dayEntries.isNotEmpty;

    return StationDayCalculationResult(
      date: date,
      pumpResults: pumpResults,
      allNozzleResults: allNozzleResults,
      totalFuelSalesPaise: totalStationFuelSalesPaise,
      totalGrossLitres: totalStationGross,
      totalTestLitres: totalStationTest,
      totalNetLitres: totalStationNet,
      totalMsLitres: totalStationMs,
      totalHsdLitres: totalStationHsd,
      recordedSalesPaise: recordedSales,
      cashSalesPaise: cash,
      phonePeSalesPaise: phonePe,
      cardSalesPaise: card,
      creditSalesPaise: credit,
      cashGivenToOwnerPaise: toOwner,
      foodExpensesPaise: food,
      otherExpensesPaise: otherDebits,
      hasData: hasData,
    );
  }

  // Dynamic Shift Reconciliation Report calculated strictly from today's real entries and pump readings
  ShiftReconciliationReport get sampleShiftReport {
    try {
      final dayCalc = getDayCalculation(DateTime.now());

      int cash = dayCalc.cashSalesPaise;
      int phonePe = dayCalc.phonePeSalesPaise;
      int card = dayCalc.cardSalesPaise;
      int credit = dayCalc.creditSalesPaise;
      int otherDebits = dayCalc.otherExpensesPaise;
      int food = dayCalc.foodExpensesPaise;
      int toOwner = dayCalc.cashGivenToOwnerPaise;

      final nozzlesToUse = dayCalc.allNozzleResults;

      int totalNozzleFuelSalesPaise = 0;
      for (final n in nozzlesToUse) {
        totalNozzleFuelSalesPaise += n.fuelSalesPaise;
      }

      if (cash == 0 && totalNozzleFuelSalesPaise > (phonePe + card + credit)) {
        cash = totalNozzleFuelSalesPaise - (phonePe + card + credit);
      }

      if (toOwner == 0) {
        toOwner = getShiftHandoverToOwnerPaise(
          activeShift,
          date: DateTime.now(),
        );
      }

      final int remainingCash = (cash - (toOwner + otherDebits + food)).clamp(
        0,
        999999999999,
      );

      return ReconciliationService.reconcileShift(
        nozzleResults: nozzlesToUse,
        cashSalesPaise: cash,
        phonePeSalesPaise: phonePe,
        cardSalesPaise: card,
        creditSalesPaise: credit,
        openingCashFloatPaise: 0,
        otherCashDebitsPaise: otherDebits,
        foodExpensesPaise: food,
        salaryExpensesPaise: 0,
        cashGivenToOwnerPaise: toOwner,
        countedClosingCashPaise: remainingCash,
      );
    } catch (e) {
      debugPrint('Error generating sampleShiftReport: $e');
      return ReconciliationService.reconcileShift(
        nozzleResults: [],
        cashSalesPaise: 0,
        phonePeSalesPaise: 0,
        cardSalesPaise: 0,
        creditSalesPaise: 0,
      );
    }
  }
}
