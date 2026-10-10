import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../models/pump.dart';
import '../models/shift.dart';
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

  // Active Logged-in User
  late UserProfile _currentUser;
  UserProfile get currentUser => _currentUser;

  // Station Settings
  StationSettings _settings = const StationSettings();
  StationSettings get settings => _settings;

  // Geofence Simulation
  bool _simulateInsideGeofence = true;
  bool get simulateInsideGeofence => _simulateInsideGeofence;

  // All Available Station Users
  List<UserProfile> _allUsers = [];
  List<UserProfile> get allUsers => _allUsers;

  // Pumps & Dispensers
  List<Pump> _pumps = [];
  List<Pump> get pumps => _pumps;

  // Current Active Shift
  late Shift _activeShift;
  Shift get activeShift => _activeShift;

  // Shifts History
  List<Shift> _allShifts = [];
  List<Shift> get allShifts => _allShifts;

  // Transaction Entries
  List<TransactionEntry> _entries = [];
  List<TransactionEntry> get entries => _entries;

  // Receipts Inbox
  List<ReceiptScan> _receipts = [];
  List<ReceiptScan> get receipts => _receipts;

  // Credit Customers (Khata)
  List<CreditCustomer> _creditCustomers = [];
  List<CreditCustomer> get creditCustomers => _creditCustomers;

  // Owner Notifications
  List<OwnerNotificationItem> _notifications = [];
  List<OwnerNotificationItem> get notifications => _notifications;

  StationStateProvider() {
    _initializeDefaultData();
  }

  void _initializeDefaultData() {
    // 1. Users
    _allUsers = [
      const UserProfile(
        id: 'owner_abhilash',
        name: 'Abhilash',
        phoneNumber: '+91 98480 12345',
        role: UserRole.owner,
        assignedShift: 'All',
        preferredLanguage: 'en',
      ),
      const UserProfile(
        id: 'mgr_ravi',
        name: 'Ravi',
        phoneNumber: '+91 94401 23456',
        role: UserRole.manager,
        assignedShift: 'Station 1',
        preferredLanguage: 'te',
      ),
      const UserProfile(
        id: 'staff_srikant',
        name: 'Srikant',
        phoneNumber: '+91 98492 34567',
        role: UserRole.shiftStaff,
        assignedShift: 'Evening',
        preferredLanguage: 'te',
      ),
      const UserProfile(
        id: 'staff_kishore',
        name: 'Kishore',
        phoneNumber: '+91 97013 45678',
        role: UserRole.shiftStaff,
        assignedShift: 'Night',
        preferredLanguage: 'te',
      ),
    ];

    // Default current user is Staff Ravi / Srikant for forecourt view
    _currentUser = _allUsers[1]; // Ravi

    // 2. Pumps & Dispensers
    // Pump 1: Serial 202501001272
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
            ratePaisePerLitre: 11752, // ₹117.52
            currentTotaliserMl: 169923720, // 169,923.720 L
            previousAcceptedReadingMl: 168676720, // 168,676.720 L
            previousReadingTimestamp: DateTime(2026, 10, 9, 21, 50),
          ),
          Nozzle(
            id: 'p1_n2',
            pumpId: 'pump_1',
            nozzleNumber: 2,
            fuelType: 'Diesel',
            ratePaisePerLitre: 10521, // ₹105.21
            currentTotaliserMl: 274487190, // 274,487.190 L
            previousAcceptedReadingMl: 273287210, // 273,287.210 L
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

    // 3. Active Shift (Morning 10 Oct 2026)
    _activeShift = Shift(
      id: 'shift_10oct_morning',
      shiftName: 'Morning',
      businessDate: '10 Oct 2026',
      staffId: 'mgr_ravi',
      staffName: 'Ravi',
      pumpName: 'Pump 1',
      status: ShiftStatus.inProgress,
      timeRange: '6:00 AM - 2:00 PM',
      openingReadingsMl: {
        1: 169923720,
        2: 274487190,
      },
      closingReadingsMl: {
        1: 170218850,
        2: 275095980,
      },
      testVolumesMl: {
        1: 5000,
        2: 5000,
      },
      cashHandoverPaise: 1307400, // ₹13,074
    );

    // 4. Historical Shifts for Review
    _allShifts = [
      _activeShift,
      Shift(
        id: 'shift_9oct_evening',
        shiftName: 'Evening',
        businessDate: '9 Oct 2026',
        staffId: 'staff_srikant',
        staffName: 'Srikant',
        pumpName: 'Pump 1',
        status: ShiftStatus.needsReview,
        timeRange: '2:00 PM - 10:00 PM',
        openingReadingsMl: {
          1: 168676720,
          2: 273287210,
        },
        closingReadingsMl: {
          1: 168971850,
          2: 273901000,
        },
        testVolumesMl: {
          1: 5000,
          2: 5000,
        },
        cashHandoverPaise: 1307400,
        handoverReceiver: 'Owner',
        handoverTime: DateTime(2026, 10, 9, 22, 0),
        note: 'Category mapping pending.',
      ),
      Shift(
        id: 'shift_9oct_night',
        shiftName: 'Night',
        businessDate: '9 Oct 2026',
        staffId: 'staff_kishore',
        staffName: 'Kishore',
        pumpName: 'Pump 2',
        status: ShiftStatus.needsReview,
        timeRange: '10:00 PM - 6:00 AM',
        openingReadingsMl: {
          1: 84120000,
          2: 134800000,
        },
        closingReadingsMl: {
          1: 84520100,
          2: 135400200,
        },
        testVolumesMl: {
          1: 5000,
          2: 5000,
        },
        cashHandoverPaise: 3058000,
        handoverReceiver: 'Owner',
        handoverTime: DateTime(2026, 10, 10, 6, 0),
        note: 'Night shift closing.',
      ),
    ];

    // 5. Money Entries from Golden Ledger Fixture
    _entries = [
      TransactionEntry(
        id: 'entry_1',
        shiftId: 'shift_9oct_evening',
        category: EntryCategory.phonePe,
        direction: EntryDirection.received,
        amountPaise: 250000, // ₹2,500
        phonePeNumber: '9848012432',
        timeString: '12:15 pm',
        reference: 'Customer UPI',
        createdAt: DateTime(2026, 10, 9, 12, 15),
        createdBy: 'Srikant',
      ),
      TransactionEntry(
        id: 'entry_2',
        shiftId: 'shift_9oct_evening',
        category: EntryCategory.phonePe,
        direction: EntryDirection.received,
        amountPaise: 3056700, // ₹30,567 (Total PhonePe = ₹33,067)
        phonePeNumber: '9440198765',
        timeString: '7:40 pm',
        reference: 'Forecourt QR scans',
        createdAt: DateTime(2026, 10, 9, 19, 40),
        createdBy: 'Srikant',
      ),
      TransactionEntry(
        id: 'entry_3',
        shiftId: 'shift_9oct_evening',
        category: EntryCategory.card,
        direction: EntryDirection.received,
        amountPaise: 453200, // ₹4,532 (swiping)
        reference: 'HDFC POS swipe',
        createdAt: DateTime(2026, 10, 9, 18, 20),
        createdBy: 'Srikant',
      ),
      TransactionEntry(
        id: 'entry_4',
        shiftId: 'shift_9oct_evening',
        category: EntryCategory.credit,
        direction: EntryDirection.received,
        amountPaise: 1800000, // ₹18,000 (Sri Sai Travels)
        reference: 'Sri Sai Travels (Bus AP16 XX1234)',
        createdAt: DateTime(2026, 10, 9, 16, 0),
        createdBy: 'Srikant',
      ),
      TransactionEntry(
        id: 'entry_5',
        shiftId: 'shift_9oct_evening',
        category: EntryCategory.credit,
        direction: EntryDirection.received,
        amountPaise: 1200000, // ₹12,000 (Local school bus)
        reference: 'Local school bus (N.C)',
        createdAt: DateTime(2026, 10, 9, 17, 30),
        createdBy: 'Srikant',
      ),
      TransactionEntry(
        id: 'entry_6',
        shiftId: 'shift_9oct_evening',
        category: EntryCategory.expense,
        direction: EntryDirection.paidOut,
        amountPaise: 1737300, // ₹17,373 (Bus Bill / Other cash debit)
        reference: 'Other cash debit (Needs owner category)',
        createdAt: DateTime(2026, 10, 9, 19, 0),
        createdBy: 'Srikant',
      ),
      TransactionEntry(
        id: 'entry_7',
        shiftId: 'shift_9oct_evening',
        category: EntryCategory.expense,
        direction: EntryDirection.paidOut,
        amountPaise: 10000, // ₹100 (Food expense / curries)
        reference: 'Food / curries',
        createdAt: DateTime(2026, 10, 9, 13, 30),
        createdBy: 'Srikant',
      ),
      TransactionEntry(
        id: 'entry_8',
        shiftId: 'shift_9oct_evening',
        category: EntryCategory.toOwner,
        direction: EntryDirection.paidOut,
        amountPaise: 1307400, // ₹13,074
        reference: 'Cash given owner',
        timeString: '10:00 pm',
        createdAt: DateTime(2026, 10, 9, 22, 0),
        createdBy: 'Srikant',
      ),
    ];

    // 6. Credit Customers Khata
    _creditCustomers = [
      CreditCustomer(
        id: 'cust_srisai',
        name: 'Sri Sai Travels',
        subtitle: 'Bus AP16 XX1234',
        pendingAmountPaise: 1800000, // ₹18,000
        lastCreditDate: DateTime(2026, 10, 9),
        payments: [
          CreditPayment(
            id: 'pay_1',
            date: DateTime(2026, 10, 8),
            amountPaise: 500000,
            mode: 'Cash',
            note: 'Advance payment',
          ),
        ],
      ),
      CreditCustomer(
        id: 'cust_schoolbus',
        name: 'Local school bus',
        subtitle: 'School Transport',
        pendingAmountPaise: 1200000, // ₹12,000
        lastCreditDate: DateTime(2026, 10, 9),
      ),
    ];

    // 7. Receipts Inbox
    _receipts = [
      ReceiptScan(
        id: 'scan_sample_9oct',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '09/10/2026',
        printedTime: '21:50:29',
        nozzleCumVolumeMl: {
          1: 169923720,
          2: 274487190,
        },
        imagePath: 'assets/images/media_1791616403909.jpg',
        validationStatus: ReceiptValidationStatus.previousDayReceipt,
        statusMessage: 'This receipt is from 9 Oct 2026. Take today\'s printout.',
        capturedBy: 'Ravi (sample)',
        capturedAt: DateTime(2026, 10, 9, 21, 51),
        locationVerified: false,
        distanceMeters: 18.5,
      ),
      ReceiptScan(
        id: 'scan_sample_srikant',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '10/10/2026',
        printedTime: '06:45:10',
        nozzleCumVolumeMl: {
          1: 170218850,
          2: 275095980,
        },
        imagePath: 'assets/images/media_1791616403909.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Verified today reading.',
        capturedBy: 'Srikant (sample)',
        capturedAt: DateTime(2026, 10, 10, 6, 46),
        locationVerified: true,
        distanceMeters: 12.0,
      ),
    ];

    // 8. Notifications
    _notifications = [
      OwnerNotificationItem(
        id: 'notif_1',
        title: 'New receipt scan from Srikant',
        subtitle: 'Pump 1 • 10 Oct 2026 06:45 • Verified',
        timestamp: DateTime(2026, 10, 10, 6, 46),
      ),
      OwnerNotificationItem(
        id: 'notif_2',
        title: 'Previous-day receipt uploaded',
        subtitle: 'Ravi scanned 9 Oct receipt for 10 Oct shift • Flagged',
        timestamp: DateTime(2026, 10, 9, 21, 51),
        isWarning: true,
      ),
      OwnerNotificationItem(
        id: 'notif_3',
        title: 'Evening shift cash handover ready',
        subtitle: '₹13,074 handed over to Owner by Srikant',
        timestamp: DateTime(2026, 10, 9, 22, 5),
      ),
    ];
  }

  // --- ACTIONS ---

  void setLanguage(String lang) {
    _currentLanguage = lang;
    notifyListeners();
  }

  void switchUser(UserProfile user) {
    _currentUser = user;
    notifyListeners();
  }

  void toggleGeofenceSimulation() {
    _simulateInsideGeofence = !_simulateInsideGeofence;
    notifyListeners();
  }

  void addTransactionEntry(TransactionEntry entry) {
    _entries.insert(0, entry);
    notifyListeners();
  }

  void saveReceiptScan(ReceiptScan scan) {
    _receipts.insert(0, scan);
    
    // Create Owner Notification
    _notifications.insert(
      0,
      OwnerNotificationItem(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        title: 'New scan uploaded: ${scan.pumpSerialNumber}',
        subtitle: scan.statusMessage,
        timestamp: DateTime.now(),
        isWarning: scan.validationStatus != ReceiptValidationStatus.valid,
      ),
    );

    notifyListeners();
  }

  void submitShiftForReview(int cashHandoverPaise) {
    _activeShift = _activeShift.copyWith(
      status: ShiftStatus.needsReview,
      cashHandoverPaise: cashHandoverPaise,
      handoverTime: DateTime.now(),
    );
    notifyListeners();
  }

  void recordCreditPayment(String customerId, int amountPaise, String mode) {
    int idx = _creditCustomers.indexWhere((c) => c.id == customerId);
    if (idx != -1) {
      CreditCustomer cust = _creditCustomers[idx];
      int updatedPending = (cust.pendingAmountPaise - amountPaise).clamp(0, double.infinity).toInt();
      List<CreditPayment> updatedPayments = List.from(cust.payments)..insert(
        0,
        CreditPayment(
          id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
          date: DateTime.now(),
          amountPaise: amountPaise,
          mode: mode,
        ),
      );
      _creditCustomers[idx] = cust.copyWith(
        pendingAmountPaise: updatedPending,
        payments: updatedPayments,
      );
      notifyListeners();
    }
  }

  void updateSettings(StationSettings newSettings) {
    _settings = newSettings;
    notifyListeners();
  }

  void addNewUser(UserProfile newUser) {
    _allUsers.add(newUser);
    notifyListeners();
  }

  void toggleUserSuspension(String userId) {
    int idx = _allUsers.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      _allUsers[idx] = _allUsers[idx].copyWith(active: !_allUsers[idx].active);
      notifyListeners();
    }
  }

  /// Calculates authoritative reconciliation report for the 9 Oct sample shift
  ShiftReconciliationReport get sampleShiftReport {
    // Petrol (Pump 1 Nozzle 1)
    NozzleCalculationResult petrol = ReconciliationService.calculateNozzle(
      nozzleNumber: 1,
      fuelType: 'Petrol',
      openingReadingMl: 168676720,
      closingReadingMl: 168971850,
      testVolumeMl: 5000,
      ratePaisePerLitre: 11752,
    );

    // Diesel (Pump 1 Nozzle 2)
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
      cashSalesPaise: 3054700, // ₹30,547
      phonePeSalesPaise: 3306700, // ₹33,067
      cardSalesPaise: 453200, // ₹4,532
      creditSalesPaise: 3000000, // ₹30,000
      openingCashFloatPaise: 0,
      otherCashDebitsPaise: 1737300, // ₹17,373
      foodExpensesPaise: 10000, // ₹100
      salaryExpensesPaise: 0,
      cashGivenToOwnerPaise: 1307400, // ₹13,074
      countedClosingCashPaise: 0,
    );
  }
}
