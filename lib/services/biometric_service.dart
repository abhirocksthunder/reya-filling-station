import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _prefBiometricEnabled = 'rfs_biometric_enabled';
  static const String _prefBiometricUserId = 'rfs_biometric_user_id';

  /// Check if device hardware supports biometric authentication (Fingerprint / Face ID)
  static Future<bool> isBiometricsSupported() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Biometrics check error: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get list of available biometric types (fingerprint, face, etc.)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Available biometrics error: $e');
      return [];
    }
  }

  /// Check if user has enabled biometric login on this device
  static Future<bool> isBiometricLoginEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefBiometricEnabled) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get the user ID linked to biometric login
  static Future<String?> getBiometricUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefBiometricUserId);
    } catch (_) {
      return null;
    }
  }

  /// Enable biometric login for a specific approved user after biometric prompt
  static Future<bool> enableBiometricLogin(String userId) async {
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: 'Scan fingerprint or face to enable biometric quick login for Reya Filling Station',
        biometricOnly: true,
      );
      if (authenticated) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefBiometricEnabled, true);
        await prefs.setString(_prefBiometricUserId, userId);
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      debugPrint('Enable biometric failed: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Disable biometric login
  static Future<void> disableBiometricLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefBiometricEnabled, false);
      await prefs.remove(_prefBiometricUserId);
    } catch (_) {}
  }

  /// Authenticate using fingerprint or face
  static Future<bool> authenticateWithBiometrics({String reason = 'Scan fingerprint or face to login to Reya Filling Station'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    } catch (_) {
      return false;
    }
  }
}
