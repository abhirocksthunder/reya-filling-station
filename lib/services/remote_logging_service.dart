import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/formatting/date_formatter.dart';

enum LogLevel { info, warn, error, fatal }

class AppLogEntry {
  final String id;
  final DateTime timestamp;
  final String timestampIst;
  final LogLevel level;
  final String screenName;
  final String action;
  final String message;
  final String? userId;
  final String? userRole;
  final Map<String, dynamic>? details;
  final String? error;
  final String? stackTrace;

  const AppLogEntry({
    required this.id,
    required this.timestamp,
    required this.timestampIst,
    required this.level,
    required this.screenName,
    required this.action,
    required this.message,
    this.userId,
    this.userRole,
    this.details,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'timestampIst': timestampIst,
    'level': level.name,
    'screenName': screenName,
    'action': action,
    'message': message,
    'userId': userId,
    'userRole': userRole,
    'details': details,
    'error': error,
    'stackTrace': stackTrace,
  };

  factory AppLogEntry.fromMap(Map<String, dynamic> map) => AppLogEntry(
    id: map['id'] ?? '',
    timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    timestampIst: map['timestampIst'] ?? '',
    level: LogLevel.values.firstWhere(
      (e) => e.name == map['level'],
      orElse: () => LogLevel.info,
    ),
    screenName: map['screenName'] ?? '',
    action: map['action'] ?? '',
    message: map['message'] ?? '',
    userId: map['userId'],
    userRole: map['userRole'],
    details: map['details'] != null ? Map<String, dynamic>.from(map['details']) : null,
    error: map['error'],
    stackTrace: map['stackTrace'],
  );
}

class RemoteLoggingService {
  static final RemoteLoggingService _instance = RemoteLoggingService._internal();
  factory RemoteLoggingService() => _instance;
  RemoteLoggingService._internal();

  static const String _stationId = 'chatrai';
  final List<AppLogEntry> _inMemoryBuffer = [];
  static const int _maxInMemory = 60;

  List<AppLogEntry> get recentLogs => List.unmodifiable(_inMemoryBuffer);

  CollectionReference<Map<String, dynamic>>? get _logsCollection {
    try {
      return FirebaseFirestore.instance
          .collection('stations')
          .doc(_stationId)
          .collection('appLogs');
    } catch (e) {
      return null;
    }
  }

  /// Logs a screen view navigation event across the app
  Future<void> logScreenView(
    String screenName, {
    String? userId,
    String? userRole,
    Map<String, dynamic>? details,
  }) async {
    await log(
      level: LogLevel.info,
      screenName: screenName,
      action: 'screen_view',
      message: 'Navigated to $screenName',
      userId: userId,
      userRole: userRole,
      details: details,
    );
  }

  /// Logs an informational message
  Future<void> logInfo(
    String message, {
    required String screenName,
    String action = 'info',
    String? userId,
    String? userRole,
    Map<String, dynamic>? details,
  }) async {
    await log(
      level: LogLevel.info,
      screenName: screenName,
      action: action,
      message: message,
      userId: userId,
      userRole: userRole,
      details: details,
    );
  }

  /// Logs a warning message
  Future<void> logWarn(
    String message, {
    required String screenName,
    String action = 'warning',
    String? userId,
    String? userRole,
    Map<String, dynamic>? details,
  }) async {
    await log(
      level: LogLevel.warn,
      screenName: screenName,
      action: action,
      message: message,
      userId: userId,
      userRole: userRole,
      details: details,
    );
  }

  /// Logs an error with optional exception and stack trace
  Future<void> logError(
    String message, {
    required String screenName,
    String action = 'error',
    dynamic error,
    StackTrace? stackTrace,
    String? userId,
    String? userRole,
    Map<String, dynamic>? details,
  }) async {
    await log(
      level: LogLevel.error,
      screenName: screenName,
      action: action,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      userId: userId,
      userRole: userRole,
      details: details,
    );
  }

  /// Core log persistence method
  Future<void> log({
    required LogLevel level,
    required String screenName,
    required String action,
    required String message,
    String? userId,
    String? userRole,
    Map<String, dynamic>? details,
    String? error,
    String? stackTrace,
  }) async {
    final now = DateTime.now();
    final logId = 'log_${now.millisecondsSinceEpoch}_${(now.microsecondsSinceEpoch % 1000)}';
    final istString = '${DateFormatter.formatDisplayDate(now)} ${DateFormatter.formatDisplayTime(now)} IST';

    final entry = AppLogEntry(
      id: logId,
      timestamp: now,
      timestampIst: istString,
      level: level,
      screenName: screenName,
      action: action,
      message: message,
      userId: userId,
      userRole: userRole,
      details: details,
      error: error,
      stackTrace: stackTrace,
    );

    // Keep circular memory buffer
    _inMemoryBuffer.insert(0, entry);
    if (_inMemoryBuffer.length > _maxInMemory) {
      _inMemoryBuffer.removeLast();
    }

    if (kDebugMode) {
      debugPrint('[RemoteLog-${level.name.toUpperCase()}] [$screenName:$action] $message ${error != null ? "Error: $error" : ""}');
    }

    // Ship to Firestore asynchronously without blocking caller
    try {
      final col = _logsCollection;
      if (col != null) {
        await col.doc(logId).set(entry.toMap());
      }
    } catch (e) {
      debugPrint('RemoteLoggingService cloud write failed (offline or uninitialized): $e');
    }
  }

  /// Removes logs older than 4 days for all logins and records failures
  Future<int> purgeLogsOlderThan({Duration age = const Duration(days: 4)}) async {
    int purgedCount = 0;
    try {
      final col = _logsCollection;
      if (col == null) return 0;

      final cutoffTime = DateTime.now().subtract(age).toUtc().toIso8601String();
      final oldDocs = await col
          .where('timestamp', isLessThan: cutoffTime)
          .limit(100)
          .get();

      if (oldDocs.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in oldDocs.docs) {
          batch.delete(doc.reference);
          purgedCount++;
        }
        await batch.commit();

        await log(
          level: LogLevel.info,
          screenName: 'SystemMaintenance',
          action: 'purge_logs_success',
          message: 'Purged $purgedCount logs older than ${age.inDays} days.',
        );
      }
    } catch (e, st) {
      debugPrint('RemoteLoggingService purge failed: $e');
      await log(
        level: LogLevel.error,
        screenName: 'SystemMaintenance',
        action: 'purge_logs_failure',
        message: 'Failed to purge logs older than ${age.inDays} days: $e',
        error: e.toString(),
        stackTrace: st.toString(),
      );
    }
    return purgedCount;
  }
}
