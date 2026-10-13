import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reya_filling_station/models/apk_release.dart';
import 'package:reya_filling_station/models/receipt_scan.dart';
import 'package:reya_filling_station/models/station_settings.dart';
import 'package:reya_filling_station/models/user_profile.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';
import 'package:reya_filling_station/services/app_version_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Shift Timings CRUD & Dynamic Sync Tests', () {
    late StationStateProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = StationStateProvider();
    });

    test('1. Default shift timings contains Morning and Night (no deleted Evening or dummy users)', () {
      final timings = provider.settings.shiftTimings;
      expect(timings.containsKey('Morning'), isTrue);
      expect(timings.containsKey('Evening'), isFalse);
      expect(timings.containsKey('Night'), isTrue);

      // Verify no dummy users (Kishore, Krishna, Srikanth) exist
      expect(provider.allUsers.any((u) => u.name.toLowerCase().contains('kishore')), isFalse);
      expect(provider.allUsers.any((u) => u.name.toLowerCase().contains('krishna')), isFalse);
      expect(provider.allUsers.any((u) => u.name.toLowerCase().contains('srikanth')), isFalse);

      // Before any staff member logs in, visibleShifts is empty
      expect(provider.visibleShifts, isEmpty);
    });

    test('2. Add new shift dynamically updates settings, allShifts and notifications', () {
      provider.addShiftTiming('General Shift', '9:00 AM - 5:00 PM');

      expect(provider.settings.shiftTimings['General Shift'], equals('9:00 AM - 5:00 PM'));
      expect(
        provider.allShifts.any((s) => s.shiftName == 'General Shift' && s.timeRange == '9:00 AM - 5:00 PM'),
        isTrue,
      );
      expect(
        provider.notifications.any((n) => n.title.contains('General Shift')),
        isTrue,
      );
    });

    test('3. Edit shift renames shift and updates timing, shifts and assigned users', () {
      final staff = provider.allUsers.firstWhere((u) => u.role == UserRole.shiftStaff);
      expect(staff.assignedShift, equals('Morning'));

      // Staff logs in -> activates Morning shift and stamps appVersion
      provider.switchUser(staff);
      final loggedInStaff = provider.allUsers.firstWhere((u) => u.id == staff.id);
      expect(loggedInStaff.appVersion, isNotEmpty);
      expect(loggedInStaff.lastSeenAt, isNotNull);
      expect(provider.visibleShifts.any((s) => s.shiftName == 'Morning'), isTrue);

      // Edit Morning shift to "Early Morning"
      provider.editShiftTiming('Morning', 'Early Morning', '5:30 AM - 1:30 PM');

      expect(provider.settings.shiftTimings.containsKey('Morning'), isFalse);
      expect(provider.settings.shiftTimings['Early Morning'], equals('5:30 AM - 1:30 PM'));

      // Verify assigned staff updated
      final updatedStaff = provider.allUsers.firstWhere((u) => u.id == staff.id);
      expect(updatedStaff.assignedShift, equals('Early Morning'));

      // Verify active shifts updated
      expect(
        provider.allShifts.any((s) => s.shiftName == 'Early Morning' && s.timeRange == '5:30 AM - 1:30 PM'),
        isTrue,
      );
    });

    test('4. Delete shift removes timing, cleans roster and unassigns staff', () {
      provider.addShiftTiming('Night Shift', '10:00 PM - 6:00 AM');
      expect(provider.settings.shiftTimings.containsKey('Night Shift'), isTrue);

      provider.deleteShiftTiming('Night Shift');
      expect(provider.settings.shiftTimings.containsKey('Night Shift'), isFalse);
      expect(provider.allShifts.any((s) => s.shiftName == 'Night Shift'), isFalse);
    });
  });

  group('APK Release & Share Link Tests', () {
    late StationStateProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = StationStateProvider();
    });

    test('1. Publishing APK release updates provider state and settings', () async {
      final release = ApkReleaseItem(
        id: 'rel_test_1',
        version: '1.0.7',
        buildNumber: 8,
        downloadUrl: 'https://reya-filling-station-chatrai.web.app/static/reya-filling-station.apk',
        fileName: 'reya-filling-station-v1.0.7.apk',
        fileSizeBytes: 92732266,
        publishedBy: 'Kalyan',
        publishedAt: DateTime.now(),
        releaseNotes: 'Dynamic shifts and APK distribution',
        active: true,
      );

      await provider.publishApkRelease(release);

      expect(provider.apkReleases.length, equals(1));
      expect(provider.apkReleases.first.id, equals('rel_test_1'));
      expect(provider.settings.latestVersion, equals('1.0.7'));
      expect(provider.settings.latestBuildNumber, equals(8));
      expect(provider.settings.updateUrl, equals('https://reya-filling-station-chatrai.web.app/static/reya-filling-station.apk'));
      expect(provider.notifications.any((n) => n.title.contains('New APK Released')), isTrue);
    });

    test('2. ApkReleaseItem formatted getters work as expected', () {
      final release = ApkReleaseItem(
        id: 'rel_test_2',
        version: '1.0.7',
        buildNumber: 8,
        downloadUrl: 'https://reya-filling-station-chatrai.web.app/static/reya-filling-station.apk',
        fileSizeBytes: 92732266,
        publishedAt: DateTime.utc(2026, 10, 10, 18, 0, 0),
      );

      expect(release.displayVersion, equals('v1.0.7+8'));
      expect(release.formattedSize, equals('88.4 MB'));
      expect(release.formattedPublishedAt, contains('10 Oct 2026'));
    });

    test('3. AppVersionService resolves relative URLs correctly', () {
      expect(
        AppVersionService.resolveDownloadUrl(
          '/static/reya-filling-station.apk',
          version: '1.0.20',
          buildNumber: 21,
        ),
        equals('https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.20+21.apk'),
      );
      expect(
        AppVersionService.resolveDownloadUrl(
          '',
          version: '1.0.20',
          buildNumber: 21,
        ),
        equals('https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.20+21.apk'),
      );
    });

    test('4. Delete APK release removes item from state', () async {
      final release = ApkReleaseItem(
        id: 'rel_to_delete',
        version: '1.0.8',
        buildNumber: 9,
        downloadUrl: 'https://example.com/apk1.apk',
        publishedAt: DateTime.now(),
      );
      await provider.publishApkRelease(release);
      expect(provider.apkReleases.any((r) => r.id == 'rel_to_delete'), isTrue);

      await provider.deleteApkRelease('rel_to_delete');
      expect(provider.apkReleases.any((r) => r.id == 'rel_to_delete'), isFalse);
    });

    test('5. purgeApkReleasesOlderThan removes releases older than 7 days and preserves recent ones', () async {
      final oldRelease = ApkReleaseItem(
        id: 'old_rel_10_days',
        version: '1.0.1',
        buildNumber: 2,
        downloadUrl: 'https://example.com/old.apk',
        publishedAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      final recentRelease = ApkReleaseItem(
        id: 'recent_rel_2_days',
        version: '1.0.8',
        buildNumber: 9,
        downloadUrl: 'https://example.com/recent.apk',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      await provider.publishApkRelease(oldRelease);
      await provider.publishApkRelease(recentRelease);
      expect(provider.apkReleases.length, equals(1));
      expect(provider.apkReleases.any((r) => r.id == oldRelease.id), isFalse);

      final purgedCount = await provider.purgeApkReleasesOlderThan(const Duration(days: 7));
      expect(purgedCount, equals(1));
      expect(provider.apkReleases.any((r) => r.id == 'old_rel_10_days'), isFalse);
      expect(provider.apkReleases.any((r) => r.id == 'recent_rel_2_days'), isTrue);
    });

    test('6. clearAllFirestoreCollections resets dispenser nozzle readings, fuel sales, credit customers, and shift handovers to zero', () async {
      final today = DateTime.now();
      provider.saveReceiptScan(ReceiptScan(
        id: 'scan_clear_test_1',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '${today.day.toString().padLeft(2, "0")}/${today.month.toString().padLeft(2, "0")}/${today.year}',
        printedTime: '10:00:00',
        nozzleCumVolumeMl: const {1: 168971850, 2: 273901000},
        imagePath: 'test/path.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Valid',
        capturedBy: 'Srinivas',
        capturedAt: today,
        reviewStatus: 'approved',
      ));
      expect(provider.getDayCalculation(today).totalFuelSalesPaise, greaterThan(0));

      await provider.clearAllFirestoreCollections();

      final afterCalc = provider.getDayCalculation(today);
      expect(afterCalc.totalNetLitres, equals(0.0));
      expect(afterCalc.totalFuelSalesPaise, equals(0));
      expect(provider.entries, isEmpty);
      expect(provider.receipts, isEmpty);
      expect(provider.creditCustomers, isEmpty);
      expect(provider.notifications, isEmpty);
      expect(provider.allShifts, isEmpty);
    });
  });

  group('Manager User Management with Owner Approval & 1-Minute Live Location Tests', () {
    late StationStateProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = StationStateProvider();
    });

    test('1. Manager adding a new user marks user as pending_approval and Owner can approve or reject', () {
      // Owner creates a Manager user first (Owner actions are immediately approved)
      final managerUser = UserProfile(
        id: 'mgr_1',
        name: 'Ramesh Manager',
        phoneNumber: '9888877777',
        role: UserRole.manager,
        securityPin: '2222',
      );
      provider.addNewUser(managerUser);
      expect(provider.allUsers.firstWhere((u) => u.id == 'mgr_1').isPendingApproval, isFalse);

      // Switch active session to Manager
      provider.switchUser(managerUser);

      // Manager adds a new Shift Staff member
      final newStaff = UserProfile(
        id: 'staff_pending_1',
        name: 'Ravi Kumar',
        phoneNumber: '9111122222',
        role: UserRole.shiftStaff,
        assignedShift: 'Morning',
        securityPin: '3333',
      );
      provider.addNewUser(newStaff);

      final added = provider.allUsers.firstWhere((u) => u.id == 'staff_pending_1');
      expect(added.isPendingApproval, isTrue);
      expect(added.hasPendingEdit, isFalse);
      expect(added.requestedBy, equals('Ramesh Manager'));
      expect(provider.pendingApprovalUsers.any((u) => u.id == 'staff_pending_1'), isTrue);
      expect(provider.notifications.any((n) => n.title.contains('User Approval Requested')), isTrue);

      // Switch back to Owner and approve the user
      final owner = provider.allUsers.firstWhere((u) => u.role == UserRole.owner);
      provider.switchUser(owner);
      provider.approveUserRequest('staff_pending_1');

      final approved = provider.allUsers.firstWhere((u) => u.id == 'staff_pending_1');
      expect(approved.isPendingApproval, isFalse);
      expect(approved.approvalStatus, equals('approved'));
      expect(provider.pendingApprovalUsers.any((u) => u.id == 'staff_pending_1'), isFalse);
    });

    test('2. Manager editing an existing approved user stages changes in pendingEditData until Owner approves or rejects', () {
      final managerUser = UserProfile(
        id: 'mgr_2',
        name: 'Suresh Manager',
        phoneNumber: '9888866666',
        role: UserRole.manager,
        securityPin: '4444',
      );
      provider.addNewUser(managerUser);
      provider.switchUser(managerUser);

      // Manager edits existing approved staff (Srinivas)
      final existingStaff = provider.allUsers.firstWhere((u) => u.role == UserRole.shiftStaff);
      final editedStaff = UserProfile(
        id: existingStaff.id,
        name: 'Srinivas Rao',
        phoneNumber: existingStaff.phoneNumber,
        role: existingStaff.role,
        assignedShift: 'Night',
        securityPin: existingStaff.securityPin,
      );
      provider.updateUser(editedStaff);

      final staged = provider.allUsers.firstWhere((u) => u.id == existingStaff.id);
      expect(staged.isPendingApproval, isTrue);
      expect(staged.hasPendingEdit, isTrue);
      // Live profile keeps original name/shift until Owner approves
      expect(staged.name, equals('Srinivas'));
      expect(staged.assignedShift, equals('Morning'));
      expect(staged.pendingEditData?['name'], equals('Srinivas Rao'));
      expect(staged.pendingEditData?['assignedShift'], equals('Night'));

      // Owner approves the staged edit
      final owner = provider.allUsers.firstWhere((u) => u.role == UserRole.owner);
      provider.switchUser(owner);
      provider.approveUserRequest(existingStaff.id);

      final afterApproval = provider.allUsers.firstWhere((u) => u.id == existingStaff.id);
      expect(afterApproval.isPendingApproval, isFalse);
      expect(afterApproval.hasPendingEdit, isFalse);
      expect(afterApproval.name, equals('Srinivas Rao'));
      expect(afterApproval.assignedShift, equals('Night'));
    });

    test('3. Live 1-minute location tracking updates user telemetry and stamps GPS coordinates on receipt scan', () {
      final staff = provider.allUsers.firstWhere((u) => u.role == UserRole.shiftStaff);
      provider.switchUser(staff);
      provider.refreshCurrentUserLocation();
      final user = provider.currentUser;
      expect(user.lastLatitude, isNotNull);
      expect(user.lastLongitude, isNotNull);
      expect(user.lastDistanceMeters, isNotNull);
      expect(user.isAtStation, isTrue);
      expect(user.locationUpdatedAt, isNotNull);

      // Toggle outside geofence simulation and verify live location telemetry updates
      provider.toggleGeofenceSimulation();
      expect(provider.currentUser.isAtStation, isFalse);
      expect(provider.currentUser.lastDistanceMeters, greaterThan(provider.settings.radiusMeters));

      // Toggle back to inside station perimeter and save a receipt scan
      provider.toggleGeofenceSimulation();
      final today = DateTime.now();
      provider.saveReceiptScan(ReceiptScan(
        id: 'scan_gps_test_1',
        pumpSerialNumber: '202501001272',
        fpId: '1',
        printedDate: '${today.day.toString().padLeft(2, "0")}/${today.month.toString().padLeft(2, "0")}/${today.year}',
        printedTime: '11:15:00',
        nozzleCumVolumeMl: const {1: 168980000},
        imagePath: 'test/gps_scan.jpg',
        validationStatus: ReceiptValidationStatus.valid,
        statusMessage: 'Valid',
        capturedBy: user.name,
        capturedAt: today,
      ));

      final savedScan = provider.receipts.firstWhere((r) => r.id == 'scan_gps_test_1');
      expect(savedScan.scanLatitude, isNotNull);
      expect(savedScan.scanLongitude, isNotNull);
      expect(savedScan.locationVerified, isTrue);
    });
  });
}
