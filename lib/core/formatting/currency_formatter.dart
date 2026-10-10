import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _inrFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _inrWithDecimalFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Formats integer paise into ₹ string without decimals if whole rupees
  static String formatPaise(int paise, {bool forceDecimals = false}) {
    double rupees = paise / 100.0;
    if (forceDecimals || (paise % 100 != 0)) {
      return _inrWithDecimalFormat.format(rupees);
    }
    return _inrFormat.format(rupees);
  }

  /// Parses a string like "13,074" or "13074.50" or "₹2,500" into integer paise
  static int parseToPaise(String input) {
    if (input.trim().isEmpty) return 0;
    String sanitized = input.replaceAll('₹', '').replaceAll(',', '').trim();
    if (sanitized.isEmpty) return 0;
    
    // Exact parsing avoiding IEEE floating-point drift
    if (sanitized.contains('.')) {
      List<String> parts = sanitized.split('.');
      int rupees = int.tryParse(parts[0]) ?? 0;
      String dec = parts[1];
      if (dec.length == 1) dec = '${dec}0';
      if (dec.length > 2) dec = dec.substring(0, 2);
      int paisePart = int.tryParse(dec) ?? 0;
      return (rupees * 100) + (rupees >= 0 ? paisePart : -paisePart);
    } else {
      int rupees = int.tryParse(sanitized) ?? 0;
      return rupees * 100;
    }
  }

  /// Formats paise/Litre rate like 11752 -> "₹117.52/L"
  static String formatRate(int paisePerLitre) {
    double rate = paisePerLitre / 100.0;
    return '₹${rate.toStringAsFixed(2)}';
  }
}
