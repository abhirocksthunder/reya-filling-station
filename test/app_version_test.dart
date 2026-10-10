import 'package:flutter_test/flutter_test.dart';
import 'package:reya_filling_station/models/station_settings.dart';
import 'package:reya_filling_station/services/app_version_service.dart';

void main() {
  group('AppVersionService Semantic Version & Force Update Tests', () {
    test('1. Identifies newer patch version', () {
      expect(AppVersionService.isRemoteNewer('1.0.3', 4, '1.0.2', 3), isTrue);
    });

    test('2. Identifies newer minor and major versions', () {
      expect(AppVersionService.isRemoteNewer('1.1.0', 1, '1.0.9', 9), isTrue);
      expect(AppVersionService.isRemoteNewer('2.0.0', 1, '1.9.9', 9), isTrue);
    });

    test('3. Rejects identical or older version', () {
      expect(AppVersionService.isRemoteNewer('1.0.2', 3, '1.0.2', 3), isFalse);
      expect(AppVersionService.isRemoteNewer('1.0.1', 2, '1.0.2', 3), isFalse);
    });

    test('4. Identifies newer build number when semver matches', () {
      expect(AppVersionService.isRemoteNewer('1.0.2', 4, '1.0.2', 3), isTrue);
      expect(AppVersionService.isRemoteNewer('1.0.2', 2, '1.0.2', 3), isFalse);
    });

    test('5. Evaluates StationSettings forceUpdate policy', () {
      const activeSettings = StationSettings(
        latestVersion: '1.0.5',
        latestBuildNumber: 6,
        forceUpdate: true,
      );
      // Compared against fallback 1.0.4+5
      expect(AppVersionService.isUpdateAvailable(activeSettings), isTrue);
      expect(AppVersionService.isForceUpdateRequired(activeSettings), isTrue);

      const optionalSettings = StationSettings(
        latestVersion: '1.0.5',
        latestBuildNumber: 6,
        forceUpdate: false,
      );
      expect(AppVersionService.isUpdateAvailable(optionalSettings), isTrue);
      expect(AppVersionService.isForceUpdateRequired(optionalSettings), isFalse);
    });
  });
}
