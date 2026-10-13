import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/formatting/date_formatter.dart';
import '../core/utils/url_launcher_helper.dart';
import 'remote_logging_service.dart';

enum AlertSeverity { high, critical, security }

class SentinelAlertItem {
  final String id;
  final DateTime timestamp;
  final String timestampIst;
  final AlertSeverity severity;
  final String title;
  final String message;
  final String targetWhatsApp;
  final String targetEmail;
  final Map<String, dynamic>? metadata;

  const SentinelAlertItem({
    required this.id,
    required this.timestamp,
    required this.timestampIst,
    required this.severity,
    required this.title,
    required this.message,
    required this.targetWhatsApp,
    required this.targetEmail,
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'timestampIst': timestampIst,
    'severity': severity.name,
    'title': title,
    'message': message,
    'targetWhatsApp': targetWhatsApp,
    'targetEmail': targetEmail,
    'metadata': metadata,
  };
}

class SentinelAlertAgent {
  static final SentinelAlertAgent _instance = SentinelAlertAgent._internal();
  factory SentinelAlertAgent() => _instance;
  SentinelAlertAgent._internal();

  static const String targetWhatsAppNumber = '+919492757943';
  static const String targetEmailAddress = 'reyafillingstation@gmail.com';
  static const String _stationId = 'chatrai';

  CollectionReference<Map<String, dynamic>>? get _alertsCollection {
    try {
      return FirebaseFirestore.instance
          .collection('stations')
          .doc(_stationId)
          .collection('sentinelAlerts');
    } catch (e) {
      return null;
    }
  }

  /// Triggers a critical red flag alert when any user gets blocked
  Future<SentinelAlertItem> notifyUserBlocked({
    required String userEmail,
    required String userName,
    required String reason,
    String? failedAttempts,
  }) async {
    final now = DateTime.now();
    final ist = '${DateFormatter.formatDisplayDate(now)} ${DateFormatter.formatDisplayTime(now)} IST';

    final text = '🚨 *REYAA FILLING STATION SECURITY ALERT*\n'
        '• Event: User Account Blocked / Locked Out\n'
        '• User: $userName ($userEmail)\n'
        '• Reason: $reason\n'
        '• Attempts: ${failedAttempts ?? "Exceeded PIN limit"}\n'
        '• Time: $ist\n'
        'Please review user credentials in the station owner dashboard.';

    return triggerRedFlag(
      title: 'User Blocked: $userName',
      message: text,
      severity: AlertSeverity.security,
      metadata: {
        'userEmail': userEmail,
        'userName': userName,
        'reason': reason,
        'attempts': failedAttempts,
      },
    );
  }

  /// Triggers generic red flag alert (e.g. Geofence violation, wrong dispenser serial, counter rollback)
  Future<SentinelAlertItem> triggerRedFlag({
    required String title,
    required String message,
    AlertSeverity severity = AlertSeverity.critical,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now();
    final alertId = 'alert_${now.millisecondsSinceEpoch}';
    final ist = '${DateFormatter.formatDisplayDate(now)} ${DateFormatter.formatDisplayTime(now)} IST';

    final item = SentinelAlertItem(
      id: alertId,
      timestamp: now,
      timestampIst: ist,
      severity: severity,
      title: title,
      message: message,
      targetWhatsApp: targetWhatsAppNumber,
      targetEmail: targetEmailAddress,
      metadata: metadata,
    );

    // 1. Log to RemoteLoggingService
    await RemoteLoggingService().log(
      level: LogLevel.fatal,
      screenName: 'SentinelAlertAgent',
      action: 'red_flag_triggered',
      message: '[$title] $message',
      details: metadata,
    );

    // 2. Persist to Firestore
    try {
      final col = _alertsCollection;
      if (col != null) {
        await col.doc(alertId).set(item.toMap());
      }
    } catch (e) {
      debugPrint('SentinelAlertAgent persistence error: $e');
    }

    return item;
  }

  /// Dispatches the alert to the Station Owner on WhatsApp (+919492757943)
  static Future<bool> openWhatsAppAlert(String alertText) async {
    return await UrlLauncherHelper.launchWhatsApp(alertText, phoneNumber: targetWhatsAppNumber);
  }

  /// Dispatches the alert to the Station Owner via Email client
  static Future<bool> openEmailAlert(String subject, String body) async {
    return await UrlLauncherHelper.launchEmail(targetEmailAddress, subject: subject, body: body);
  }
}
