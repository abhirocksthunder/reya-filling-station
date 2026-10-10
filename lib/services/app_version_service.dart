import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/station_settings.dart';
import '../widgets/force_update_dialog.dart';

class AppVersionService {
  static const String fallbackVersion = '1.0.4';
  static const int fallbackBuildNumber = 5;

  static String _version = fallbackVersion;
  static int _buildNumber = fallbackBuildNumber;
  static bool _initialized = false;

  static String get version => _version;
  static int get buildNumber => _buildNumber;
  static String get displayVersion => 'v$_version+$_buildNumber';

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version.isNotEmpty ? info.version : fallbackVersion;
      _buildNumber = int.tryParse(info.buildNumber) ?? fallbackBuildNumber;
      _initialized = true;
    } catch (e) {
      debugPrint('AppVersionService: PackageInfo fallback used ($e)');
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

  /// Formats the complete download URL (resolving local IPs or relative paths)
  static String resolveDownloadUrl(String rawUrl) {
    if (rawUrl.isEmpty) {
      return '/static/reya-filling-station.apk';
    }
    return rawUrl;
  }

  static bool _dialogShowing = false;

  /// Checks if an update is required and prompts the user
  static Future<void> checkAndPromptUpdate(
    BuildContext context,
    StationSettings settings,
  ) async {
    await init();
    if (_dialogShowing) return;
    if (isForceUpdateRequired(settings)) {
      _dialogShowing = true;
      if (context.mounted) {
        // Dynamic import / call to avoid cyclic dependency
        await ForceUpdateDialog.show(context, settings);
        _dialogShowing = false;
      }
    }
  }

  /// Opens the APK download URL in browser/download manager
  static Future<bool> launchDownload(String url) async {
    try {
      final uri = Uri.parse(resolveDownloadUrl(url));
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Failed to launch update URL: $e');
      return false;
    }
  }
}
