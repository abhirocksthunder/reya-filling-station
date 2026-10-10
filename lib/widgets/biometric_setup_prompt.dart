import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/colors.dart';
import '../models/user_profile.dart';
import '../services/biometric_service.dart';

class BiometricSetupPrompt {
  static const String _prefPromptPrefix = 'rfs_biometric_prompted_';

  /// Shows the biometric setup prompt once the user logs in, if hardware supports it
  static Future<void> checkAndShowPrompt(BuildContext context, UserProfile user) async {
    final supported = await BiometricService.isBiometricsSupported();
    if (!supported) return;

    final isEnabled = await BiometricService.isBiometricLoginEnabled();
    if (isEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool('$_prefPromptPrefix${user.id}') ?? false;
    if (alreadyPrompted) return;

    // Mark as prompted for this user session so it doesn't repeatedly popup
    await prefs.setBool('$_prefPromptPrefix${user.id}', true);

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: StationColors.primary, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Setup Biometric Login',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi ${user.name}, would you like to enable fingerprint or face recognition for quick and secure access on this device?',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StationColors.primaryLight.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: StationColors.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Station credentials remain protected with your device hardware biometric vault.',
                      style: TextStyle(fontSize: 12, color: StationColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip for Now', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.fingerprint, color: Colors.white, size: 18),
            label: const Text('Enable Biometrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: StationColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await BiometricService.enableBiometricLogin(user.id);
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Biometric login enabled successfully!'),
                      backgroundColor: StationColors.successGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Biometric authentication cancelled or not recognized.'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
