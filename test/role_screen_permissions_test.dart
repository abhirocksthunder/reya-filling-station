import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reya_filling_station/models/station_settings.dart';
import 'package:reya_filling_station/models/user_profile.dart';
import 'package:reya_filling_station/services/station_state_provider.dart';

void main() {
  group('Roles & Screen Permissions Governance Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Default role screen permissions match expected screens for Owner, Manager, and Shift Staff', () {
      const settings = StationSettings();

      const ownerUser = UserProfile(
        id: 'owner_1',
        name: 'Owner',
        email: 'owner@rfs.com',
        phoneNumber: '9999999999',
        role: UserRole.owner,
      );
      const managerUser = UserProfile(
        id: 'mgr_1',
        name: 'Manager',
        email: 'mgr@rfs.com',
        phoneNumber: '8888888888',
        role: UserRole.manager,
      );
      const staffUser = UserProfile(
        id: 'staff_1',
        name: 'Staff',
        email: 'staff@rfs.com',
        phoneNumber: '7777777777',
        role: UserRole.shiftStaff,
      );

      final ownerScreens = settings.getScreensForUser(ownerUser);
      final managerScreens = settings.getScreensForUser(managerUser);
      final staffScreens = settings.getScreensForUser(staffUser);

      expect(ownerScreens.length, 13);
      expect(managerScreens, [
        'my_shift',
        'scan_receipt',
        'money_entries',
        'close_shift',
        'people_management',
      ]);
      expect(staffScreens, [
        'my_shift',
        'scan_receipt',
        'money_entries',
        'close_shift',
      ]);
    });

    test('2. Owner can configure Manager role to Users Only or custom screens dynamically', () async {
      final provider = StationStateProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      const managerUser = UserProfile(
        id: 'mgr_2',
        name: 'Manager 2',
        email: 'mgr2@rfs.com',
        phoneNumber: '8888888881',
        role: UserRole.manager,
      );

      // Update Manager role to Users Only
      provider.updateRoleScreenPermissions('manager', ['people_management']);
      expect(provider.getAllowedScreensForUser(managerUser), ['people_management']);
      expect(provider.canAccessScreen('people_management', managerUser), isTrue);
      expect(provider.canAccessScreen('my_shift', managerUser), isFalse);

      // Toggle scan_receipt ON for manager
      provider.toggleRoleScreenPermission('manager', 'scan_receipt', true);
      expect(provider.getAllowedScreensForUser(managerUser), [
        'people_management',
        'scan_receipt',
      ]);

      // Reset Manager role to default
      provider.resetRoleScreenPermissionsToDefault('manager');
      expect(provider.getAllowedScreensForUser(managerUser), [
        'my_shift',
        'scan_receipt',
        'money_entries',
        'close_shift',
        'people_management',
      ]);
    });

    test('3. Per-user custom permissions override role default permissions', () {
      const settings = StationSettings();
      const customStaffUser = UserProfile(
        id: 'staff_custom',
        name: 'Custom Staff',
        email: 'custom@rfs.com',
        phoneNumber: '7777777771',
        role: UserRole.shiftStaff,
        permissions: ['my_shift', 'scan_receipt'],
      );

      expect(settings.getScreensForUser(customStaffUser), [
        'my_shift',
        'scan_receipt',
      ]);
    });

    test('4. Owner core screens cannot be locked out', () {
      const settings = StationSettings(
        roleScreenPermissions: {
          'owner': ['my_shift'],
        },
      );
      const ownerUser = UserProfile(
        id: 'owner_1',
        name: 'Owner',
        email: 'owner@rfs.com',
        phoneNumber: '9999999999',
        role: UserRole.owner,
      );

      final screens = settings.getScreensForUser(ownerUser);
      expect(screens.contains('station_overview'), isTrue);
      expect(screens.contains('people_management'), isTrue);
      expect(screens.contains('station_settings'), isTrue);
    });

    test('5. isSelfUser identifies the currently logged-in user by ID or phone', () async {
      final provider = StationStateProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      const srinivas = UserProfile(
        id: 'user_1791642830525',
        name: 'Srinivas',
        email: 'srinivas@rfs.com',
        phoneNumber: '9533677647',
        role: UserRole.manager,
      );
      const otherUser = UserProfile(
        id: 'owner_kalyan',
        name: 'Kalyan',
        email: 'kalyan@rfs.com',
        phoneNumber: '9848011111',
        role: UserRole.owner,
      );

      expect(provider.isSelfUser(srinivas), isFalse);
      provider.switchUser(srinivas);
      expect(provider.isSelfUser(srinivas), isTrue);
      expect(provider.isSelfUser(otherUser), isFalse);
    });
  });
}
