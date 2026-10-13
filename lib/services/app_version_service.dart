import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/utils/url_launcher_helper.dart';
import '../models/station_settings.dart';
import '../widgets/force_update_dialog.dart';

class AppVersionService {
  static const String fallbackVersion = '1.0.33';
  static const int fallbackBuildNumber = 34;

  static String _version = fallbackVersion;
  static int _buildNumber = fallbackBuildNumber;
  static bool _initialized = false;

  static String get version => _version;
  static int get buildNumber => _buildNumber;
  static String get displayVersion => 'v$_version+$_buildNumber';

  static String defaultHostedApkUrl([String? ver, int? build]) {
    final v = (ver != null && ver.trim().isNotEmpty) ? ver.trim() : fallbackVersion;
    final b = build ?? fallbackBuildNumber;
    return 'https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v$v+$b.apk';
  }

  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      // In web browser, avoid PackageInfo platform channel which throws MissingPluginException
      _version = fallbackVersion;
      _buildNumber = fallbackBuildNumber;
      _initialized = true;
      return;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version.isNotEmpty ? info.version : fallbackVersion;
      _buildNumber = int.tryParse(info.buildNumber) ?? fallbackBuildNumber;
      _initialized = true;
    } catch (e) {
      _version = fallbackVersion;
      _buildNumber = fallbackBuildNumber;
      _initialized = true;
    }
  }

  /// Compares remote version with current local version.
  /// Returns true if remote is newer.
  static bool isRemoteNewer(
    String remoteVersion,
    int remoteBuild,
    String localVersion,
    int localBuild,
  ) {
    List<int> parseParts(String v) {
      return v
          .split(RegExp(r'[\.\+]'))
          .map((s) => int.tryParse(s) ?? 0)
          .toList();
    }

    final remoteParts = parseParts(remoteVersion);
    final localParts = parseParts(localVersion);

    final maxLen = remoteParts.length > localParts.length ? remoteParts.length : localParts.length;

    for (int i = 0; i < maxLen; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final l = i < localParts.length ? localParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }

    // If semver parts are identical, compare build number
    return remoteBuild > localBuild;
  }

  /// Evaluates whether an update is available according to station settings
  static bool isUpdateAvailable(StationSettings settings) {
    return isRemoteNewer(
      settings.latestVersion,
      settings.latestBuildNumber,
      _version,
      _buildNumber,
    );
  }

  /// Evaluates whether a force update should block user interaction
  static bool isForceUpdateRequired(StationSettings settings) {
    if (!settings.forceUpdate) return false;
    return isUpdateAvailable(settings);
  }

  /// Formats the complete download URL with the version embedded in the filename/query
  static String resolveDownloadUrl(
    String rawUrl, {
    String? version,
    int? buildNumber,
  }) {
    final ver = (version != null && version.trim().isNotEmpty) ? version.trim() : fallbackVersion;
    final build = buildNumber ?? fallbackBuildNumber;
    final clean = rawUrl.trim();

    if (clean.isEmpty) {
      return defaultHostedApkUrl(ver, build);
    }

    // Upgrade unversioned or older versioned official hosting APK path to current target version
    if (clean.contains('/static/reya-filling-station') && clean.contains('.apk')) {
      final prefix = clean.startsWith('http')
          ? clean.substring(0, clean.indexOf('/static/reya-filling-station'))
          : 'https://reya-filling-station-chatrai.web.app';
      return '$prefix/static/reya-filling-station-v$ver+$build.apk';
    }

    return clean;
  }

  static bool _dialogShowing = false;
  static String? _lastPromptedVersionKey;

  /// Checks if an update is available/required and prompts the user in real time
  static Future<void> checkAndPromptUpdate(
    BuildContext context,
    StationSettings settings,
  ) async {
    // Web clients are continuously updated via Firebase Hosting; APK force updates are scoped to mobile
    if (kIsWeb) return;
    await init();
    if (_dialogShowing) return;
    if (isUpdateAvailable(settings)) {
      final versionKey = '${settings.latestVersion}+${settings.latestBuildNumber}_${settings.forceUpdate}';
      if (!settings.forceUpdate && _lastPromptedVersionKey == versionKey) {
        return;
      }
      _dialogShowing = true;
      _lastPromptedVersionKey = versionKey;
      if (context.mounted) {
        await ForceUpdateDialog.show(
          context,
          settings,
          previewMode: !settings.forceUpdate,
        );
        _dialogShowing = false;
      } else {
        _dialogShowing = false;
      }
    }
  }

  /// Opens the APK download URL in browser/download manager safely across platforms
  static Future<bool> launchDownload(
    String url, {
    String? version,
    int? buildNumber,
  }) async {
    final fullUrl = resolveDownloadUrl(url, version: version, buildNumber: buildNumber);
    return await UrlLauncherHelper.launchUniversalUrl(fullUrl);
  }
}
