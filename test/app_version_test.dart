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
        latestVersion: AppVersionService.fallbackVersion,
        latestBuildNumber: AppVersionService.fallbackBuildNumber + 1,
        forceUpdate: true,
      );
      // A newer base build is independent of any applied OTA patch.
      expect(AppVersionService.isUpdateAvailable(activeSettings), isTrue);
      expect(AppVersionService.isForceUpdateRequired(activeSettings), isTrue);

      const optionalSettings = StationSettings(
        latestVersion: AppVersionService.fallbackVersion,
        latestBuildNumber: AppVersionService.fallbackBuildNumber + 1,
        forceUpdate: false,
      );
      expect(AppVersionService.isUpdateAvailable(optionalSettings), isTrue);
      expect(AppVersionService.isForceUpdateRequired(optionalSettings), isFalse);
    });

    test('Current release does not prompt itself to update', () {
      expect(AppVersionService.isUpdateAvailable(const StationSettings()), isFalse);
      expect(AppVersionService.isForceUpdateRequired(const StationSettings()), isFalse);
    });

    test('6. Embeds version and build number into official APK download link', () {
      final resolved = AppVersionService.resolveDownloadUrl(
        'https://reya-filling-station-chatrai.web.app/static/reya-filling-station.apk',
        version: '1.0.19',
        buildNumber: 20,
      );
      expect(
        resolved,
        'https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.19+20.apk',
      );
    });
  });
}
