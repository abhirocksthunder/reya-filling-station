import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'web_launcher_stub.dart'
    if (dart.library.js) 'web_launcher_web.dart';

class UrlLauncherHelper {
  /// Safely launches a URL across Web, Android, iOS, and Desktop.
  /// On Web, directly uses browser window.open via JS interop to completely bypass
  /// MissingPluginException on method channels.
  static Future<bool> launchUniversalUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return false;

    if (kIsWeb) {
      try {
        final opened = openBrowserWindow(clean);
        if (opened) return true;
      } catch (e) {
        debugPrint('Web JS window.open fallback for $clean: $e');
      }
    }

    try {
      final uri = Uri.parse(clean);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      try {
        final fallbackUri = Uri.parse(clean);
        return await launchUrl(fallbackUri, mode: LaunchMode.platformDefault);
      } catch (e2) {
        debugPrint('Native launchUrl failed for $clean: $e2');
        return false;
      }
    }
  }

  /// Specialized helper for WhatsApp deep links
  static Future<bool> launchWhatsApp(String text, {String? phoneNumber}) async {
    final cleanPhone = phoneNumber != null ? phoneNumber.replaceAll(RegExp(r'[^0-9]'), '') : '';
    final url = cleanPhone.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(text)}';
    return await launchUniversalUrl(url);
  }

  /// Specialized helper for Email links
  static Future<bool> launchEmail(String email, {String? subject, String? body}) async {
    final params = <String>[];
    if (subject != null) params.add('subject=${Uri.encodeComponent(subject)}');
    if (body != null) params.add('body=${Uri.encodeComponent(body)}');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final url = 'mailto:$email$query';
    return await launchUniversalUrl(url);
  }
}
