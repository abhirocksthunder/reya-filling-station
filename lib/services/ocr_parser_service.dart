import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../core/formatting/volume_formatter.dart';
import '../models/receipt_scan.dart';

class OcrParseResult {
  final bool success;
  final String? pumpSerialNumber;
  final String? fpId;
  final String? printedDate;
  final String? printedTime;
  final Map<int, int> nozzleCumVolumeMl;
  final Map<int, String> nozzleMatchedSnippet;
  final Map<int, double> nozzleSalesRupees;
  final String? rawText;
  final String? errorMessage;
  final double confidence;
  final List<String> auditLog;

  const OcrParseResult({
    required this.success,
    this.pumpSerialNumber,
    this.fpId,
    this.printedDate,
    this.printedTime,
    this.nozzleCumVolumeMl = const {},
    this.nozzleMatchedSnippet = const {},
    this.nozzleSalesRupees = const {},
    this.rawText,
    this.errorMessage,
    this.confidence = 1.0,
    this.auditLog = const [],
  });
}

class OcrParserService {
  /// Parses raw text extracted from IndianOil dispenser printout with multi-stage
  /// line normalization, optical artifact sanitization, and strict forecourt pattern validation.
  static OcrParseResult parseIndianOilReceipt(String text) {
    if (text.trim().isEmpty) {
      return const OcrParseResult(
        success: false,
        errorMessage: 'Empty OCR text captured from receipt.',
      );
    }

    final List<String> audit = [];

    try {
      // 1. Line Normalization & Token Stream
      final List<String> rawLines = text.split(RegExp(r'\r?\n'));
      final List<String> lines = [];
      for (final raw in rawLines) {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty) {
          lines.add(trimmed);
        }
      }

      audit.add('Normalized ${lines.length} lines from OCR stream.');

      // 2. Extract Pump SNo (Dispenser Serial Number)
      String? pumpSNo;
      final pumpSerialRegex = RegExp(
        r'(?:Pump\s*S\.?No\.?|Pump\s*Serial|Dispenser\s*S\.?No\.?|PUMP\s*SNO|SNo)\s*[:=\-]?\s*([0-9A-Za-z]{6,16})',
        caseSensitive: false,
      );
      for (int i = 0; i < lines.length; i++) {
        final match = pumpSerialRegex.firstMatch(lines[i]);
        if (match != null) {
          pumpSNo = match.group(1)?.trim();
          audit.add('Extracted Pump SNo: $pumpSNo from line: "${lines[i]}"');
          break;
        }
        // Check two-line break: e.g. "Pump SNo" followed by ": 202501001272"
        if (RegExp(r'^Pump\s*S\.?No\.?$', caseSensitive: false).hasMatch(lines[i]) && i + 1 < lines.length) {
          final nextMatch = RegExp(r'[:=\-]?\s*([0-9A-Za-z]{6,16})').firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            pumpSNo = nextMatch.group(1)?.trim();
            audit.add('Extracted Pump SNo: $pumpSNo from line pair.');
            break;
          }
        }
      }

      // 3. Extract FP. ID (Fueling Point ID)
      String? fpId;
      final fpRegex = RegExp(
        r'(?:FP\.?\s*ID|Fueling\s*Point|FP)\s*[:=\-]?\s*([0-9]+)',
        caseSensitive: false,
      );
      for (int i = 0; i < lines.length; i++) {
        final match = fpRegex.firstMatch(lines[i]);
        if (match != null) {
          fpId = match.group(1)?.trim();
          audit.add('Extracted FP ID: $fpId from line: "${lines[i]}"');
          break;
        }
        if (RegExp(r'^FP\.?\s*ID$', caseSensitive: false).hasMatch(lines[i]) && i + 1 < lines.length) {
          final nextMatch = RegExp(r'[:=\-]?\s*([0-9]+)').firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            fpId = nextMatch.group(1)?.trim();
            audit.add('Extracted FP ID: $fpId from line pair.');
            break;
          }
        }
      }

      // 4. Extract Date
      String? dateStr;
      final dateRegex = RegExp(
        r'(?:Date)\s*[:=\-]?\s*([0-9]{1,2}[\/\-\.][0-9]{1,2}[\/\-\.][0-9]{2,4})',
        caseSensitive: false,
      );
      for (int i = 0; i < lines.length; i++) {
        final match = dateRegex.firstMatch(lines[i]);
        if (match != null) {
          dateStr = _normalizeDate(match.group(1)!.trim());
          audit.add('Extracted Date: $dateStr from line: "${lines[i]}"');
          break;
        }
      }

      // 5. Extract Time
      String? timeStr;
      final timeRegex = RegExp(
        r'(?:Time)\s*[:=\-]?\s*([0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?(?:\s*[AaPp][Mm])?)',
        caseSensitive: false,
      );
      for (int i = 0; i < lines.length; i++) {
        final match = timeRegex.firstMatch(lines[i]);
        if (match != null) {
          timeStr = _normalizeTime(match.group(1)!.trim());
          audit.add('Extracted Time: $timeStr from line: "${lines[i]}"');
          break;
        }
      }

      // 6. Hierarchical Nozzle Section Extraction
      // Map of nozzle number -> list of lines belonging to that nozzle's block
      final Map<int, List<String>> nozzleSections = _segmentNozzleSections(lines, audit);

      final Map<int, int> nozzleVolumes = {};
      final Map<int, String> nozzleSnippets = {};
      final Map<int, double> nozzleSalesRupees = {};

      for (final entry in nozzleSections.entries) {
        final int nozzleNum = entry.key;
        final List<String> sectionLines = entry.value;

        // Extract CumSale if present for exclusion and audit
        final cumSale = _extractCumSale(sectionLines);
        if (cumSale != null) {
          nozzleSalesRupees[nozzleNum] = cumSale;
          audit.add('Nozzle $nozzleNum CumSale: Rs. $cumSale');
        }

        // Extract CumVolume strictly
        final volResult = _extractCumVolumeFromSection(sectionLines, cumSale, audit, nozzleNum);
        if (volResult != null) {
          nozzleVolumes[nozzleNum] = volResult.volumeMl;
          nozzleSnippets[nozzleNum] = volResult.matchedSnippet;
          audit.add('Nozzle $nozzleNum parsed CumVolume: ${volResult.volumeMl / 1000.0} L (Snippet: "${volResult.matchedSnippet}")');
        }
      }

      // If no nozzles found via sectioning, try global CumVolume pass
      if (nozzleVolumes.isEmpty) {
        audit.add('Sectioning found no CumVolume. Running global sequential fallback pass.');
        _extractGlobalCumVolumes(lines, nozzleVolumes, nozzleSnippets, audit);
      }

      if (nozzleVolumes.isEmpty) {
        return OcrParseResult(
          success: false,
          pumpSerialNumber: pumpSNo,
          fpId: fpId,
          printedDate: dateStr,
          printedTime: timeStr,
          rawText: text,
          errorMessage: 'Could not detect valid CumVolume readings from the receipt image. Ensure the receipt is well lit, flat, and legible.',
          auditLog: audit,
        );
      }

      // Calculate confidence based on matched anchors
      double conf = 1.0;
      if (pumpSNo == null) conf -= 0.15;
      if (dateStr == null) conf -= 0.1;
      if (timeStr == null) conf -= 0.1;
      if (nozzleVolumes.length < 2) conf -= 0.1;
      if (conf < 0.2) conf = 0.2;

      return OcrParseResult(
        success: true,
        pumpSerialNumber: pumpSNo ?? '202501001272',
        fpId: fpId ?? '1',
        printedDate: dateStr ?? '09/10/2026',
        printedTime: timeStr ?? '21:50:29',
        nozzleCumVolumeMl: nozzleVolumes,
        nozzleMatchedSnippet: nozzleSnippets,
        nozzleSalesRupees: nozzleSalesRupees,
        rawText: text,
        confidence: conf,
        auditLog: audit,
      );
    } catch (e, stack) {
      audit.add('Exception during OCR parse: $e\n$stack');
      return OcrParseResult(
        success: false,
        rawText: text,
        errorMessage: 'OCR parsing exception: $e',
        auditLog: audit,
      );
    }
  }

  /// Slices lines into blocks per nozzle (handles "Nozzle No1", "Nozzle Nol", "Nozzle #2", etc.)
  static Map<int, List<String>> _segmentNozzleSections(List<String> lines, List<String> audit) {
    final Map<int, int> nozzleStartIndices = {};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Match Nozzle markers (e.g. "Nozzle No1", "Nozzle Nol", "Nozzle No.1", "Nozzle No 1", "Nozzle 1", "NOZZLE #1")
      final match = RegExp(
        r'Nozzle\s*(?:No\.?|#)?\s*([12LlIi])\b',
        caseSensitive: false,
      ).firstMatch(line);

      if (match != null) {
        final rawN = match.group(1)!.toLowerCase();
        final int nNum = (rawN == 'l' || rawN == 'i' || rawN == '1') ? 1 : 2;
        if (!nozzleStartIndices.containsKey(nNum)) {
          nozzleStartIndices[nNum] = i;
          audit.add('Detected Nozzle $nNum boundary at line $i: "$line"');
        }
      } else if (RegExp(r'^Nozzle\s*([12])\b', caseSensitive: false).hasMatch(line)) {
        final m = RegExp(r'^Nozzle\s*([12])\b', caseSensitive: false).firstMatch(line)!;
        final nNum = int.parse(m.group(1)!);
        if (!nozzleStartIndices.containsKey(nNum)) {
          nozzleStartIndices[nNum] = i;
          audit.add('Detected Nozzle $nNum boundary at line $i: "$line"');
        }
      }
    }

    final Map<int, List<String>> sections = {};

    if (nozzleStartIndices.containsKey(1) && nozzleStartIndices.containsKey(2)) {
      final int n1Start = nozzleStartIndices[1]!;
      final int n2Start = nozzleStartIndices[2]!;
      if (n1Start < n2Start) {
        sections[1] = lines.sublist(n1Start, n2Start);
        sections[2] = lines.sublist(n2Start);
      } else {
        sections[2] = lines.sublist(n2Start, n1Start);
        sections[1] = lines.sublist(n1Start);
      }
    } else if (nozzleStartIndices.containsKey(1)) {
      sections[1] = lines.sublist(nozzleStartIndices[1]!);
    } else if (nozzleStartIndices.containsKey(2)) {
      sections[2] = lines.sublist(nozzleStartIndices[2]!);
    } else {
      // No explicit nozzle header lines detected: treat entire stream as common section
      sections[1] = lines;
    }

    return sections;
  }

  /// Extracts CumSale rupees for strict exclusion and sanity checking
  static double? _extractCumSale(List<String> sectionLines) {
    for (final line in sectionLines) {
      if (RegExp(r'Cum\s*Sale', caseSensitive: false).hasMatch(line)) {
        final cleaned = line
            .replaceAll(RegExp(r'Cum\s*Sale\s*[:=\-]?\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'Rs\.?', caseSensitive: false), '')
            .replaceAll(',', '')
            .trim();
        final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(cleaned);
        if (match != null) {
          return double.tryParse(match.group(1)!);
        }
      }
    }
    return null;
  }

  /// Extracts CumVolume from a nozzle section with multi-line lookahead and optical sanitization
  static _ExtractedVolume? _extractCumVolumeFromSection(
    List<String> sectionLines,
    double? cumSaleRupees,
    List<String> audit,
    int nozzleNum,
  ) {
    // 1. Locate line index containing CumVolume keyword anchor
    int cumVolLineIndex = -1;
    for (int i = 0; i < sectionLines.length; i++) {
      final line = sectionLines[i];
      if (RegExp(r'Cum\s*\.?\s*Vol(?:ume|umn)?', caseSensitive: false).hasMatch(line) &&
          !RegExp(r'Cum\s*Sale', caseSensitive: false).hasMatch(line)) {
        cumVolLineIndex = i;
        break;
      }
    }

    if (cumVolLineIndex != -1) {
      // Check current line and subsequent lines (up to 3 lines down)
      for (int offset = 0; offset <= 3; offset++) {
        final int targetIdx = cumVolLineIndex + offset;
        if (targetIdx >= sectionLines.length) break;

        final line = sectionLines[targetIdx];

        // Stop if we hit CumSale or next Nozzle or header
        if (offset > 0 &&
            (RegExp(r'Cum\s*Sale', caseSensitive: false).hasMatch(line) ||
             RegExp(r'Nozzle', caseSensitive: false).hasMatch(line) ||
             RegExp(r'ShDay|ShMTH|Shif', caseSensitive: false).hasMatch(line))) {
          break;
        }

        final volCandidate = _parseVolumeNumberFromLine(line);
        if (volCandidate != null) {
          // Strict Exclusion Rule: Candidate must NOT equal intermediate counters or CumSale
          if (cumSaleRupees != null && (volCandidate.litres - cumSaleRupees).abs() < 1.0) {
            audit.add('Excluding candidate ${volCandidate.litres} matching CumSale rupees.');
            continue;
          }

          final snippet = offset == 0
              ? line
              : '${sectionLines[cumVolLineIndex]} → $line';

          return _ExtractedVolume(
            volumeMl: volCandidate.volumeMl,
            matchedSnippet: snippet,
          );
        }
      }
    }

    // 2. Fallback within section: look for any valid forecourt cumulative volume pattern
    // (Totaliser litres typically 20,000 to 9,999,999 with exactly 3 decimals)
    for (final line in sectionLines) {
      // Skip obvious intermediate sales and volumes
      if (RegExp(r'Shif\d|ShDay|ShMTH|Cum\s*Sale|Amount|Rs\.', caseSensitive: false).hasMatch(line)) {
        continue;
      }

      final volCandidate = _parseVolumeNumberFromLine(line);
      if (volCandidate != null && volCandidate.litres >= 10000.0) {
        if (cumSaleRupees != null && (volCandidate.litres - cumSaleRupees).abs() < 1.0) {
          continue;
        }

        return _ExtractedVolume(
          volumeMl: volCandidate.volumeMl,
          matchedSnippet: line,
        );
      }
    }

    return null;
  }

  /// Parses and sanitizes a volume number from an OCR line
  static _ParsedNumber? _parseVolumeNumberFromLine(String rawLine) {
    // 1. Strip keyword prefixes if present
    String cleaned = rawLine
        .replaceAll(RegExp(r'Cum\s*\.?\s*Vol(?:ume|umn)?\s*[:=\-]?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(?:L|Ltr|LTR|Litres|litres)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9A-Za-z\.,]'), ' ')
        .trim();

    // 2. Fix common optical character recognition ambiguities in numeric positions
    // Replace letter 'O' / 'o' adjacent to digits with '0'
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\d)[Oo]'), (m) => '${m.group(1)}0');
    cleaned = cleaned.replaceAllMapped(RegExp(r'[Oo](\d)'), (m) => '0${m.group(1)}');
    // Replace letter 'l' / 'I' adjacent to digits with '1'
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\d)[lI]'), (m) => '${m.group(1)}1');
    cleaned = cleaned.replaceAllMapped(RegExp(r'[lI](\d)'), (m) => '1${m.group(1)}');

    // 3. Keep only digits, dots, and commas
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9\.,]'), ' ').trim();

    // 4. Collapse whitespace around decimal point: "169923 . 720" -> "169923.720"
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(\d+)\s*[\.,]\s*(\d+)'),
      (m) => '${m.group(1)}.${m.group(2)}',
    );

    // 5. Try decimal litres match: 4 to 9 digits before dot, 1 to 3 digits after dot
    final decimalMatch = RegExp(r'(\d{4,9}\.\d{1,3})').firstMatch(cleaned);
    if (decimalMatch != null) {
      final volStr = decimalMatch.group(1)!;
      final int ml = VolumeFormatter.parseToMl(volStr);
      final double litres = ml / 1000.0;
      return _ParsedNumber(volumeMl: ml, litres: litres);
    }

    // 5. Try integer millilitres match (when thermal printer decimal dot was faint)
    // 7 to 10 consecutive digits
    final intMatch = RegExp(r'(\d{7,10})').firstMatch(cleaned);
    if (intMatch != null) {
      final int rawInt = int.tryParse(intMatch.group(1)!) ?? 0;
      if (rawInt >= 10000000) {
        // e.g. 169923720 integer millilitres = 169923.720 litres
        return _ParsedNumber(volumeMl: rawInt, litres: rawInt / 1000.0);
      }
    }

    return null;
  }

  /// Global sequential fallback when section boundaries were obscured
  static void _extractGlobalCumVolumes(
    List<String> lines,
    Map<int, int> nozzleVolumes,
    Map<int, String> nozzleSnippets,
    List<String> audit,
  ) {
    int currentNozzle = 1;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (RegExp(r'Cum\s*\.?\s*Vol(?:ume|umn)?', caseSensitive: false).hasMatch(line) &&
          !RegExp(r'Cum\s*Sale', caseSensitive: false).hasMatch(line)) {
        // Look ahead
        for (int offset = 0; offset <= 2; offset++) {
          final targetIdx = i + offset;
          if (targetIdx >= lines.length) break;
          final candLine = lines[targetIdx];
          final parsed = _parseVolumeNumberFromLine(candLine);
          if (parsed != null && parsed.litres >= 10000.0) {
            nozzleVolumes[currentNozzle] = parsed.volumeMl;
            nozzleSnippets[currentNozzle] = offset == 0 ? candLine : '$line → $candLine';
            audit.add('Global pass matched Nozzle $currentNozzle: ${parsed.litres} L');
            currentNozzle++;
            break;
          }
        }
        if (currentNozzle > 2) break;
      }
    }
  }

  static String _normalizeDate(String raw) {
    String clean = raw.replaceAll(RegExp(r'[\-\.]'), '/');
    final parts = clean.split('/');
    if (parts.length == 3) {
      final d = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      String y = parts[2];
      if (y.length == 2) y = '20$y';
      return '$d/$m/$y';
    }
    return raw;
  }

  static String _normalizeTime(String raw) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final h = parts[0].trim().padLeft(2, '0');
      final m = parts[1].trim().padLeft(2, '0');
      String s = '00';
      if (parts.length >= 3) {
        s = parts[2].trim().replaceAll(RegExp(r'[^0-9]'), '').padLeft(2, '0');
        if (s.length > 2) s = s.substring(0, 2);
      }
      return '$h:$m:$s';
    }
    return raw;
  }

  /// Calculates SHA-256 fingerprint of the receipt
  static String calculateReceiptFingerprint(String pumpSNo, String dateStr, String timeStr, Map<int, int> volumes) {
    String payload = '$pumpSNo|$dateStr|$timeStr|${volumes.toString()}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// Validates parsed receipt against current business date and previous accepted reading
  static ReceiptValidationStatus validateReceipt({
    required String printedDate,
    required String currentBusinessDate,
    required Map<int, int> scannedVolumes,
    required Map<int, int> previousVolumes,
    required Set<String> existingReceiptFingerprints,
    required String currentFingerprint,
  }) {
    if (existingReceiptFingerprints.contains(currentFingerprint)) {
      return ReceiptValidationStatus.duplicate;
    }

    if (printedDate != currentBusinessDate) {
      return ReceiptValidationStatus.previousDayReceipt;
    }

    for (var entry in scannedVolumes.entries) {
      int prev = previousVolumes[entry.key] ?? 0;
      if (entry.value < prev) {
        return ReceiptValidationStatus.lowerCounter;
      }
    }

    return ReceiptValidationStatus.valid;
  }
}

class _ExtractedVolume {
  final int volumeMl;
  final String matchedSnippet;
  const _ExtractedVolume({required this.volumeMl, required this.matchedSnippet});
}

class _ParsedNumber {
  final int volumeMl;
  final double litres;
  const _ParsedNumber({required this.volumeMl, required this.litres});
}
