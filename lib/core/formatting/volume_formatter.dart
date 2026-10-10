import 'package:intl/intl.dart';

class VolumeFormatter {
  static final NumberFormat _volumeFormat = NumberFormat('#,##0.000', 'en_IN');

  /// Formats integer millilitres to standard forecourt display string with unit: "168,923.720 L"
  static String formatMl(int millilitres, {bool includeUnit = true}) {
    double litres = millilitres / 1000.0;
    String formatted = _volumeFormat.format(litres);
    return includeUnit ? '$formatted L' : formatted;
  }

  /// Parses a decimal string (e.g. "169923.720" or "5.0") into integer millilitres
  /// without floating-point representation inaccuracies
  static int parseToMl(String input) {
    if (input.trim().isEmpty) return 0;
    String sanitized = input.replaceAll('L', '').replaceAll(',', '').trim();
    if (sanitized.isEmpty) return 0;

    if (sanitized.contains('.')) {
      List<String> parts = sanitized.split('.');
      int wholeLitres = int.tryParse(parts[0]) ?? 0;
      String dec = parts[1];
      if (dec.length == 1) dec = '${dec}00';
      if (dec.length == 2) dec = '${dec}0';
      if (dec.length > 3) dec = dec.substring(0, 3);
      int mlFraction = int.tryParse(dec) ?? 0;
      return (wholeLitres * 1000) + (wholeLitres >= 0 ? mlFraction : -mlFraction);
    } else {
      int wholeLitres = int.tryParse(sanitized) ?? 0;
      return wholeLitres * 1000;
    }
  }

  /// Converts millilitres to double litres for display when strictly required
  static double toLitres(int ml) => ml / 1000.0;
}
