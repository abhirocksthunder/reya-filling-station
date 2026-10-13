import 'package:intl/intl.dart';

class DateFormatter {
  // IST offset is UTC +05:30
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Converts any DateTime to Indian Standard Time (IST)
  static DateTime toIST(DateTime dateTime) {
    DateTime utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return utc.add(istOffset);
  }

  /// Formats date to IndianOil receipt printed format: "09/10/2026"
  static String formatReceiptDate(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(toIST(dateTime));
  }

  /// Formats time to IndianOil receipt printed format: "21:50:29"
  static String formatReceiptTime(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(toIST(dateTime));
  }

  /// Formats date for display: "10 Oct 2026"
  static String formatDisplayDate(DateTime dateTime) {
    return DateFormat('d MMM yyyy').format(toIST(dateTime));
  }

  /// Formats date & time for display: "9 Oct 2026 • 10:00 pm"
  static String formatDisplayDateTime(DateTime dateTime) {
    return DateFormat('d MMM yyyy • h:mm a').format(toIST(dateTime));
  }

  /// Formats time only: "12:15 pm"
  static String formatDisplayTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(toIST(dateTime));
  }

  /// Formats IST time with explicit IST suffix: "12:15 pm IST"
  static String formatTimeIST(DateTime dateTime) {
    return '${DateFormat('h:mm a').format(toIST(dateTime))} IST';
  }

  /// Formats IST date & time with explicit IST suffix: "10 Oct 2026, 12:15 pm IST"
  static String formatDateTimeIST(DateTime dateTime) {
    return '${DateFormat('d MMM yyyy, h:mm a').format(toIST(dateTime))} IST';
  }

  /// Formats IST timestamp as required by AIPCC guidelines: "10 Oct 2026 2:05 pm"
  static String formatAipccTimestamp(DateTime dateTime) {
    return DateFormat('d MMM yyyy h:mm a').format(toIST(dateTime));
  }

  /// Parses dd/MM/yyyy into DateTime
  static DateTime? parseReceiptDate(String dateStr) {
    try {
      List<String> parts = dateStr.trim().split('/');
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        return DateTime.utc(year, month, day);
      }
    } catch (_) {}
    return null;
  }
}
