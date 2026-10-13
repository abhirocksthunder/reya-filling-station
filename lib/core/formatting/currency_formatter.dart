import 'package:flutter/services.dart';
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

  static final NumberFormat _plainInrDecimalFormat = NumberFormat(
    '#,##,##0.00',
    'en_IN',
  );

  static final NumberFormat _plainInrIntFormat = NumberFormat.decimalPattern(
    'en_IN',
  );

  /// Formats integer paise into ₹ string with Indian commas and 2 decimal places (e.g. ₹12,000.00)
  static String formatPaise(int paise, {bool forceDecimals = true}) {
    double rupees = paise / 100.0;
    if (forceDecimals || (paise % 100 != 0)) {
      return _inrWithDecimalFormat.format(rupees);
    }
    return _inrFormat.format(rupees);
  }

  /// Formats integer paise for text boxes with Indian commas and 2 decimals (without ₹ symbol, e.g. "12,000.00")
  static String formatRupeesInput(int paise) {
    return _plainInrDecimalFormat.format(paise / 100.0);
  }

  /// Formats raw numeric text with Indian commas while preserving decimal input
  static String formatRawInputWithCommas(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return '';

    final parts = cleaned.split('.');
    final intDigits = parts[0];
    String formattedInt = '';
    if (intDigits.isNotEmpty) {
      final parsedInt = int.tryParse(intDigits);
      formattedInt = parsedInt != null
          ? _plainInrIntFormat.format(parsedInt)
          : intDigits;
    } else if (parts.length > 1) {
      formattedInt = '0';
    }

    if (parts.length > 1) {
      String decPart = parts.sublist(1).join('');
      if (decPart.length > 2) {
        decPart = decPart.substring(0, 2);
      }
      return '$formattedInt.$decPart';
    }
    return formattedInt;
  }

  /// Parses a string like "13,074" or "13,074.50" or "₹2,500.00" into integer paise
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
    return _inrWithDecimalFormat.format(rate);
  }
}

/// TextInputFormatter that formats numbers with Indian commas (e.g. 12,000.50)
/// while allowing live decimal entry up to 2 decimal places.
class IndianCurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final formatted = CurrencyFormatter.formatRawInputWithCommas(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

