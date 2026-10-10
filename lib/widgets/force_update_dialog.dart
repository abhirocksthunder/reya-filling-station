import 'package:flutter/material.dart';
import '../models/station_settings.dart';
import '../services/app_version_service.dart';
import '../core/constants/colors.dart';

class ForceUpdateDialog extends StatelessWidget {
  final StationSettings settings;
  final bool previewMode;

  const ForceUpdateDialog({
    super.key,
    required this.settings,
    this.previewMode = false,
  });

  static Future<void> show(
    BuildContext context,
    StationSettings settings, {
    bool previewMode = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: previewMode,
      builder: (BuildContext ctx) => ForceUpdateDialog(
        settings: settings,
        previewMode: previewMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentVer = AppVersionService.version;
    final currentBuild = AppVersionService.buildNumber;
    final targetVer = settings.latestVersion;
    final targetBuild = settings.latestBuildNumber;

    return PopScope(
      canPop: previewMode,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: StationColors.accentOrangeLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_alt,
                color: StationColors.accentOrange,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: StationColors.textDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'యాప్ అప్‌డేట్ అవసరం',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: StationColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A newer version of Reya Filling Station is available and required for secure forecourt synchronization.',
              style: TextStyle(fontSize: 13, height: 1.4, color: StationColors.textDark),
            ),
            const SizedBox(height: 14),
            // Version comparison chips
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: StationColors.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Installed Version', style: TextStyle(fontSize: 11, color: StationColors.textLight)),
                      const SizedBox(height: 2),
                      Text(
                        'v$currentVer+$currentBuild',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, size: 18, color: StationColors.textLight),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Latest Release', style: TextStyle(fontSize: 11, color: StationColors.primary)),
                      const SizedBox(height: 2),
                      Text(
                        'v$targetVer+$targetBuild',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: StationColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (settings.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: StationColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StationColors.successGreen.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What\'s New (కొత్త విశేషాలు):',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: StationColors.successGreen),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settings.releaseNotes,
                      style: const TextStyle(fontSize: 12, height: 1.35, color: StationColors.textDark),
                    ),
                  ],
                ),
              ),
            ],
            if (previewMode) ...[
              const SizedBox(height: 10),
              const Text(
                'Preview Mode (Admin test view)',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amber),
              ),
            ],
          ],
        ),
        actions: [
          if (previewMode)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss Preview'),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: StationColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download, size: 20),
            label: const Text(
              'Update Now · అప్‌డేట్ చేయండి',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              AppVersionService.launchDownload(settings.updateUrl);
            },
          ),
        ],
      ),
    );
  }
}
