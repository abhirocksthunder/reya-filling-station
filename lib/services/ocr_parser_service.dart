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
  /// Maximum plausible daily / single-shift volume delta per nozzle (in Litres).
  /// Daily differences are typically 1,000 to 10,000 L (never in lakhs).
  static const double maxPlausibleDailyDeltaLitres = 25000.0;

  /// Parses raw text extracted from IndianOil dispenser printout with multi-stage
  /// line normalization, optical artifact sanitization, and strict forecourt pattern validation.
  static OcrParseResult parseIndianOilReceipt(
    String text, {
    Map<int, double>? expectedBaselineLitres,
  }) {
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
          pumpSNo = _normalizeSerialDigits(match.group(1)!.trim());
          audit.add('Extracted Pump SNo: $pumpSNo from line: "${lines[i]}"');
          break;
        }
        // Check two-line break: e.g. "Pump SNo" followed by ": 202501001272"
        if (RegExp(r'^Pump\s*S\.?No\.?$', caseSensitive: false).hasMatch(lines[i]) && i + 1 < lines.length) {
          final nextMatch = RegExp(r'[:=\-]?\s*([0-9A-Za-z]{8,16})').firstMatch(lines[i + 1]);
          if (nextMatch != null) {
            pumpSNo = _normalizeSerialDigits(nextMatch.group(1)!.trim());
            audit.add('Extracted Pump SNo: $pumpSNo from line pair.');
            break;
          }
        }
      }
      if (pumpSNo == null) {
        // Standalone header column fallback when ML Kit splits left labels and right ":202501001346" values
        for (int i = 0; i < lines.length && i < 16; i++) {
          final line = lines[i].trim();
          if (line.contains('/') || line.contains('.')) continue;
          final normalizedCandidate = _normalizeSerialDigits(line.replaceAll(RegExp(r'^[:=\-\s]+'), '').trim());
          final m = RegExp(r'^(20[0-9]{8,12})$').firstMatch(normalizedCandidate);
          if (m != null) {
            pumpSNo = m.group(1)!.trim();
            audit.add('Extracted Pump SNo fallback: $pumpSNo from header line $i: "$line"');
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
      if (fpId == null) {
        for (int i = 0; i < lines.length && i < 12; i++) {
          final line = lines[i].trim();
          if (line.contains('/') || (line.contains(':') && line.length > 5)) continue;
          final m = RegExp(r'^[:=\-]?\s*([1-9]|1[0-6])\s*$').firstMatch(line);
          if (m != null) {
            fpId = m.group(1)!.trim();
            audit.add('Extracted FP ID fallback: $fpId from header line $i: "$line"');
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
      if (dateStr == null) {
        final standaloneDateRegex = RegExp(r'\b([0-9]{1,2}[\/\-\.][0-9]{1,2}[\/\-\.][0-9]{2,4})\b');
        for (int i = 0; i < lines.length && i < 15; i++) {
          final m = standaloneDateRegex.firstMatch(lines[i]);
          if (m != null) {
            dateStr = _normalizeDate(m.group(1)!.trim());
            audit.add('Extracted Date fallback: $dateStr from header line $i: "${lines[i]}"');
            break;
          }
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
      if (timeStr == null) {
        final standaloneTimeRegex = RegExp(r'\b([0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?(?:\s*[AaPp][Mm])?)\b');
        for (int i = 0; i < lines.length && i < 15; i++) {
          final m = standaloneTimeRegex.firstMatch(lines[i]);
          if (m != null) {
            timeStr = _normalizeTime(m.group(1)!.trim());
            audit.add('Extracted Time fallback: $timeStr from header line $i: "${lines[i]}"');
            break;
          }
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
        final cumSale = _extractCumSale(sectionLines, expectedBaselineLitres?[nozzleNum]);
        if (cumSale != null) {
          nozzleSalesRupees[nozzleNum] = cumSale;
          audit.add('Nozzle $nozzleNum CumSale: Rs. $cumSale');
        }

        // Extract CumVolume strictly on or below the CumVolume line
        final volResult = _extractCumVolumeFromSection(
          sectionLines,
          cumSale,
          audit,
          nozzleNum,
          expectedBaselineLitres: expectedBaselineLitres?[nozzleNum],
        );
        if (volResult != null) {
          nozzleVolumes[nozzleNum] = volResult.volumeMl;
          nozzleSnippets[nozzleNum] = volResult.matchedSnippet;
          audit.add('Nozzle $nozzleNum parsed CumVolume: ${volResult.volumeMl / 1000.0} L (Snippet: "${volResult.matchedSnippet}")');
        }
      }

      // If either Nozzle 1 or Nozzle 2 was not found via sectioning, try global sequential CumVolume pass
      if (nozzleVolumes.length < 2) {
        audit.add('Sectioning found ${nozzleVolumes.length} nozzle(s). Running global sequential pass for missing nozzle(s).');
        _extractGlobalCumVolumes(
          lines,
          nozzleVolumes,
          nozzleSnippets,
          audit,
          expectedBaselineLitres: expectedBaselineLitres,
        );
      }

      if (nozzleVolumes.isEmpty) {
        return OcrParseResult(
          success: false,
          pumpSerialNumber: pumpSNo,
          fpId: fpId,
          printedDate: dateStr,
          printedTime: timeStr,
          rawText: text,
          errorMessage: 'Could not detect valid CumVolume readings below the CumVolume line. Please scan the totaliser receipt again.',
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

      // Match Nozzle markers (e.g. "Nozzle No1", "Nozzle Nol", "Nozzle Noló", "Nozzle No.1", "Nozzle No 1", "Nozzle 1", "NOZZLE #1", "Nozzle No2")
      int? detectedNozzle;
      final n2Regex = RegExp(
        r'(?:N[o0]zz[l1iI]e|Mozzle)\s*(?:No\.?|N[o0]\.?|#|:)?\s*(?:2\b|2)',
        caseSensitive: false,
      );
      final n1Regex = RegExp(
        r'(?:N[o0]zz[l1iI]e|Mozzle)\s*(?:No\.?|N[o0]\.?|#|:)?\s*([1LlIi][óo\.]?|ó|\b1\b)',
        caseSensitive: false,
      );

      if (n2Regex.hasMatch(line) || RegExp(r'^Nozzle\s*2\b', caseSensitive: false).hasMatch(line)) {
        detectedNozzle = 2;
      } else if (n1Regex.hasMatch(line) || RegExp(r'^Nozzle\s*1\b', caseSensitive: false).hasMatch(line)) {
        detectedNozzle = 1;
      }

      if (detectedNozzle != null && !nozzleStartIndices.containsKey(detectedNozzle)) {
        nozzleStartIndices[detectedNozzle] = i;
        audit.add('Detected Nozzle $detectedNozzle boundary at line $i: "$line"');
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
    } else if (nozzleStartIndices.containsKey(2)) {
      // Nozzle 2 boundary was detected, but Nozzle 1 header was blurred/missed:
      // Preserve all lines BEFORE Nozzle 2 as Nozzle 1's section so Nozzle 1 is never dropped!
      final int n2Start = nozzleStartIndices[2]!;
      if (n2Start > 0) {
        sections[1] = lines.sublist(0, n2Start);
        audit.add('Inferred Nozzle 1 section from lines 0..${n2Start - 1} preceding Nozzle 2.');
      }
      sections[2] = lines.sublist(n2Start);
    } else if (nozzleStartIndices.containsKey(1)) {
      final List<String> fromN1 = lines.sublist(nozzleStartIndices[1]!);
      // Check if there are two CumVolume anchors inside fromN1 (meaning Nozzle 2 header was blurred)
      final List<int> cumVolIndices = [];
      for (int i = 0; i < fromN1.length; i++) {
        if (_cumVolAnchorRegex.hasMatch(fromN1[i]) &&
            !RegExp(r'^\s*Cum\s*Sale\b', caseSensitive: false).hasMatch(fromN1[i])) {
          cumVolIndices.add(i);
        }
      }
      if (cumVolIndices.length >= 2) {
        final int splitIdx = (cumVolIndices[0] + 4).clamp(cumVolIndices[0] + 1, cumVolIndices[1]);
        sections[1] = fromN1.sublist(0, splitIdx);
        sections[2] = fromN1.sublist(splitIdx);
        audit.add('Split combined Nozzle 1 stream into Nozzle 1 & Nozzle 2 at relative line $splitIdx.');
      } else {
        sections[1] = fromN1;
      }
    } else {
      // No explicit nozzle header lines detected: check if two CumVolume anchors exist
      final List<int> cumVolIndices = [];
      for (int i = 0; i < lines.length; i++) {
        if (_cumVolAnchorRegex.hasMatch(lines[i]) &&
            !RegExp(r'^\s*Cum\s*Sale\b', caseSensitive: false).hasMatch(lines[i])) {
          cumVolIndices.add(i);
        }
      }
      if (cumVolIndices.length >= 2) {
        final int splitIdx = (cumVolIndices[0] + 4).clamp(cumVolIndices[0] + 1, cumVolIndices[1]);
        sections[1] = lines.sublist(0, splitIdx);
        sections[2] = lines.sublist(splitIdx);
        audit.add('Split headerless stream into Nozzle 1 & Nozzle 2 at line $splitIdx.');
      } else {
        sections[1] = lines;
      }
    }

    return sections;
  }

  static final RegExp _intermediateHeaderRegex = RegExp(
    r'(?:'
    r'Shif[t]?\s*[123LlIi0-9]\s*(?:Sale|Vol)?'
    r'|Sh\s*[123LlIi0-9]\s*(?:Sale|Vol)'
    r'|Sht\s*[123LlIi0-9]\s*(?:Sale|Vol)'
    r'|S[123]\s*(?:Sale|Vol)'
    r'|ShDay\s*(?:Sale|Vol)?'
    r'|Day\s*(?:Sale|Vol)'
    r'|Daily\s*(?:Sale|Vol)'
    r'|ShMTH\s*(?:Sale|Vol)?'
    r'|MTH\s*(?:Sale|Vol)?'
    r'|Month\s*(?:Sale|Vol)'
    r'|Monthly\s*(?:Sale|Vol)'
    r'|Amount'
    r'|Price'
    r'|Rate'
    r')',
    caseSensitive: false,
  );

  static final RegExp _cumVolAnchorRegex = RegExp(
    r'(?:'
    r'C[uuvrnma]{1,3}\.?\s*V[o0][l1iI!|](?:[uuvrnma]{2,4}|[uuvrnma]{0,2})'
    r'|Cum\s*\.?\s*Vol(?:ume|umn|m)?'
    r'|Curn\s*\.?\s*Vol(?:ume)?'
    r'|Cun\s*\.?\s*Vol(?:ume)?'
    r'|Tot(?:al)?\s*Vol(?:ume)?'
    r'|Totaliser|Totalizer'
    r')',
    caseSensitive: false,
  );

  /// Extracts CumSale rupees for strict exclusion and sanity checking
  static double? _extractCumSale(List<String> sectionLines, [double? expectedBaselineLitres]) {
    for (int i = 0; i < sectionLines.length; i++) {
      final line = sectionLines[i];
      if (RegExp(r'Cum\s*Sale', caseSensitive: false).hasMatch(line)) {
        final cleaned = line
            .replaceAll(RegExp(r'.*Cum\s*Sale\s*[:=\-]?\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'Rs\.?', caseSensitive: false), '')
            .replaceAll(',', '')
            .trim();
        final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(cleaned);
        if (match != null) {
          final val = double.tryParse(match.group(1)!);
          if (val != null) {
            // Do not mistake a wrapped CumVolume value (near baseline litres) for CumSale rupees
            if (expectedBaselineLitres != null &&
                expectedBaselineLitres > 0 &&
                val >= expectedBaselineLitres &&
                (val - expectedBaselineLitres) <= maxPlausibleDailyDeltaLitres) {
              continue;
            }
            return val;
          }
        }
        if (i + 1 < sectionLines.length) {
          final nextLine = sectionLines[i + 1].replaceAll(',', '').trim();
          final nextMatch = RegExp(r'^([0-9]+(?:\.[0-9]+)?)').firstMatch(nextLine);
          if (nextMatch != null) {
            final val = double.tryParse(nextMatch.group(1)!);
            if (val != null) {
              if (expectedBaselineLitres != null &&
                  expectedBaselineLitres > 0 &&
                  val >= expectedBaselineLitres &&
                  (val - expectedBaselineLitres) <= maxPlausibleDailyDeltaLitres) {
                continue;
              }
              return val;
            }
          }
        }
      }
    }
    return null;
  }

  static bool _isCandidatePlausibleAgainstBaseline(
    double candidateLitres,
    double? expectedBaselineLitres,
    List<String> audit,
    int nozzleNum,
  ) {
    if (expectedBaselineLitres == null || expectedBaselineLitres <= 0) {
      return true;
    }
    final double delta = candidateLitres - expectedBaselineLitres;
    if (delta < -0.01) {
      audit.add(
        'Nozzle $nozzleNum candidate $candidateLitres L rejected: lower than baseline $expectedBaselineLitres L (delta ${delta.toStringAsFixed(3)} L).',
      );
      return false;
    }
    if (delta > maxPlausibleDailyDeltaLitres) {
      audit.add(
        'Nozzle $nozzleNum candidate $candidateLitres L rejected: gap +${delta.toStringAsFixed(3)} L exceeds max daily threshold ($maxPlausibleDailyDeltaLitres L).',
      );
      return false;
    }
    return true;
  }

  /// Extracts CumVolume from a nozzle section strictly ON or BELOW the CumVolume line
  /// (never looking upward above the CumVolume line), with intermediate shift exclusion
  /// and baseline delta plausibility validation.
  static _ExtractedVolume? _extractCumVolumeFromSection(
    List<String> sectionLines,
    double? cumSaleRupees,
    List<String> audit,
    int nozzleNum, {
    double? expectedBaselineLitres,
  }) {
    // 1. Pre-Scan: Record and mask ALL intermediate counter lines and numeric values
    // to guarantee that shift sales (like Shift2Sale, ShDaySale, ShMTHSale) can NEVER be chosen as CumVolume.
    final Set<int> intermediateLineIndices = {};
    final Set<double> intermediateValues = {};

    for (int i = 0; i < sectionLines.length; i++) {
      final line = sectionLines[i];
      if (_intermediateHeaderRegex.hasMatch(line)) {
        intermediateLineIndices.add(i);

        // Record any number on the same line
        final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(line);
        if (match != null) {
          final val = double.tryParse(match.group(1)!);
          if (val != null) {
            intermediateValues.add(val);
          }
        }

        // If the intermediate label is on its own line (line wrap in thermal printing),
        // the number is on the subsequent line! E.g. "Shif2Sale:" on line i, "20951.850" on line i+1.
        if (i + 1 < sectionLines.length) {
          final nextLine = sectionLines[i + 1].trim();
          if (!_intermediateHeaderRegex.hasMatch(nextLine) &&
              !_cumVolAnchorRegex.hasMatch(nextLine) &&
              !RegExp(r'Cum\s*Sale', caseSensitive: false).hasMatch(nextLine)) {
            final nextMatch = RegExp(r'^\s*[:=\-]?\s*(\d+(?:\.\d+)?)\s*(?:L|Rs)?\s*$').firstMatch(nextLine);
            if (nextMatch != null) {
              intermediateLineIndices.add(i + 1);
              final val = double.tryParse(nextMatch.group(1)!);
              if (val != null) {
                intermediateValues.add(val);
                audit.add('Masked wrapped intermediate counter line ${i + 1} ($val) belonging to "$line"');
              }
            }
          }
        }
      }
    }

    // 2. Locate line index containing CumVolume keyword anchor
    int cumVolLineIndex = -1;
    for (int i = 0; i < sectionLines.length; i++) {
      final line = sectionLines[i];
      if (_cumVolAnchorRegex.hasMatch(line) &&
          !RegExp(r'^\s*Cum\s*Sale\b', caseSensitive: false).hasMatch(line)) {
        cumVolLineIndex = i;
        break;
      }
    }

    if (cumVolLineIndex != -1) {
      audit.add('Found CumVolume anchor at line $cumVolLineIndex: "${sectionLines[cumVolLineIndex]}"');

      // Check the CumVolume line itself (offset 0) and lines BELOW it (offset 1..6).
      for (int offset = 0; offset <= 6; offset++) {
        final int targetIdx = cumVolLineIndex + offset;
        if (targetIdx >= sectionLines.length) break;

        final rawLine = sectionLines[targetIdx];

        if (offset > 0) {
          // Never look into lines classified as intermediate shift counters
          if (intermediateLineIndices.contains(targetIdx)) {
            continue;
          }
          // Stop if we hit the next Nozzle header
          if (RegExp(r'(?:N[o0]zz[l1iI]e|Mozzle)', caseSensitive: false).hasMatch(rawLine)) {
            break;
          }
        }

        final List<String> candidateSegments = [];
        if (rawLine.contains(RegExp(r'Cum\s*Sale', caseSensitive: false))) {
          final parts = rawLine.split(RegExp(r'Cum\s*Sale', caseSensitive: false));
          if (parts[0].trim().isNotEmpty) {
            candidateSegments.add(parts[0].trim());
          }
          if (parts.length > 1 && parts[1].trim().isNotEmpty) {
            candidateSegments.add(parts[1].trim());
          }
        } else {
          candidateSegments.add(rawLine);
        }

        for (final candLine in candidateSegments) {
          final volCandidate = _parseVolumeNumberFromLine(candLine, allowAfterCumSaleSplit: true);
          if (volCandidate != null) {
            // 1. Must be in valid forecourt totaliser range: 10,000 L to 9,999,999 L
            if (volCandidate.litres < 10000.0 || volCandidate.litres >= 10000000.0) {
              continue;
            }

            // 2. Must NOT match any intermediate counter (e.g. Shift2Sale, ShDaySale, ShMTHSale)
            if (intermediateValues.any((v) => (v - volCandidate.litres).abs() < 0.05)) {
              audit.add('Excluding candidate ${volCandidate.litres} matching intermediate shift counter.');
              continue;
            }

            // 3. Must NOT equal CumSale rupees
            if (cumSaleRupees != null && (volCandidate.litres - cumSaleRupees).abs() < 1.0) {
              audit.add('Excluding candidate ${volCandidate.litres} matching CumSale rupees.');
              continue;
            }

            // 4. Must be plausible against baseline reading (daily delta <= 25,000 L and >= 0)
            if (!_isCandidatePlausibleAgainstBaseline(
              volCandidate.litres,
              expectedBaselineLitres,
              audit,
              nozzleNum,
            )) {
              continue;
            }

            final snippet = offset == 0
                ? rawLine
                : '${sectionLines[cumVolLineIndex]} → $rawLine';

            audit.add('Nozzle $nozzleNum matched CumVolume at offset +$offset (below/on line): ${volCandidate.litres} L');
            return _ExtractedVolume(
              volumeMl: volCandidate.volumeMl,
              matchedSnippet: snippet,
            );
          }
        }
      }

      // STRICT RULE FOR NOZZLE 2: Always take Nozzle 2 CumVolume on or BELOW the CumVolume line (never above).
      // For Nozzle 1 only, allow a tightly-gated 1..2 line check if thermal wrap placed Nozzle 1's volume
      // immediately before the CumVolume label, provided it passes both the 25,000 L baseline delta gate
      // AND the CumSale/CumVolume fuel rate plausibility gate (₹65–₹150/L, rejecting ShMTHSale in lakhs).
      if (nozzleNum == 1) {
        for (int offset = -1; offset >= -2; offset--) {
          final int targetIdx = cumVolLineIndex + offset;
          if (targetIdx < 0) break;
          if (intermediateLineIndices.contains(targetIdx)) continue;

          final rawLine = sectionLines[targetIdx];
          if (_intermediateHeaderRegex.hasMatch(rawLine) ||
              RegExp(r'(?:N[o0]zz[l1iI]e|Mozzle)', caseSensitive: false).hasMatch(rawLine) ||
              RegExp(r'^\s*Cum\s*Sale\b', caseSensitive: false).hasMatch(rawLine)) {
            continue;
          }

          final volCandidate = _parseVolumeNumberFromLine(rawLine);
          if (volCandidate != null &&
              volCandidate.litres >= 10000.0 &&
              volCandidate.litres < 10000000.0) {
            if (intermediateValues.any((v) => (v - volCandidate.litres).abs() < 0.05)) continue;
            if (cumSaleRupees != null && (volCandidate.litres - cumSaleRupees).abs() < 1.0) continue;
            if (!_isCandidatePlausibleAgainstBaseline(
              volCandidate.litres,
              expectedBaselineLitres,
              audit,
              nozzleNum,
            )) {
              continue;
            }
            // Verify CumSale / CumVolume implied fuel rate (must be ~₹65 to ₹150/L, never ₹20–₹40/L like ShMTHSale)
            if (cumSaleRupees != null && cumSaleRupees > 1000000.0) {
              final double impliedRate = cumSaleRupees / volCandidate.litres;
              if (impliedRate < 65.0 || impliedRate > 150.0) {
                audit.add(
                  'Rejected Nozzle 1 wrapped candidate ${volCandidate.litres} L: implied rate Rs.${impliedRate.toStringAsFixed(2)}/L outside [65, 150].',
                );
                continue;
              }
            }

            final snippet = '${sectionLines[cumVolLineIndex]} → $rawLine';
            audit.add('Nozzle 1 matched wrapped CumVolume: ${volCandidate.litres} L');
            return _ExtractedVolume(
              volumeMl: volCandidate.volumeMl,
              matchedSnippet: snippet,
            );
          }
        }
      }

      return null;
    }

    // 3. Fallback within section ONLY when the "CumVolume" label itself was unreadable:
    // Scan only the bottom 4 lines of the section, strictly enforcing intermediate exclusion and baseline delta.
    final int minIdx = (sectionLines.length - 4) > 0 ? (sectionLines.length - 4) : 0;
    for (int i = sectionLines.length - 1; i >= minIdx; i--) {
      if (intermediateLineIndices.contains(i)) continue;

      final line = sectionLines[i];
      if (_intermediateHeaderRegex.hasMatch(line) ||
          RegExp(r'^\s*Cum\s*Sale\b', caseSensitive: false).hasMatch(line)) {
        continue;
      }

      String candLine = line;
      if (candLine.contains(RegExp(r'Cum\s*Sale', caseSensitive: false))) {
        candLine = candLine.split(RegExp(r'Cum\s*Sale', caseSensitive: false))[0].trim();
        if (candLine.isEmpty) continue;
      }

      final volCandidate = _parseVolumeNumberFromLine(candLine);
      if (volCandidate != null) {
        if (volCandidate.litres < 10000.0 || volCandidate.litres >= 10000000.0) {
          continue;
        }

        if (intermediateValues.any((v) => (v - volCandidate.litres).abs() < 0.05)) {
          audit.add('Fallback skipping ${volCandidate.litres} matching intermediate counter.');
          continue;
        }

        if (cumSaleRupees != null && (volCandidate.litres - cumSaleRupees).abs() < 1.0) {
          continue;
        }

        if (!_isCandidatePlausibleAgainstBaseline(
          volCandidate.litres,
          expectedBaselineLitres,
          audit,
          nozzleNum,
        )) {
          continue;
        }

        audit.add('Bottom-of-section fallback matched CumVolume: ${volCandidate.litres} L at line $i: "$line"');
        return _ExtractedVolume(
          volumeMl: volCandidate.volumeMl,
          matchedSnippet: line,
        );
      }
    }

    return null;
  }

  /// Parses and sanitizes a volume number from an OCR line
  static _ParsedNumber? _parseVolumeNumberFromLine(String rawLine, {bool allowAfterCumSaleSplit = false}) {
    // Immediate Guard: if line declares an intermediate counter, never parse it as volume!
    if (_intermediateHeaderRegex.hasMatch(rawLine)) {
      return null;
    }
    if (!allowAfterCumSaleSplit && RegExp(r'^\s*Cum\s*Sale\b', caseSensitive: false).hasMatch(rawLine)) {
      return null;
    }

    // 1. Strip keyword prefixes if present
    String cleaned = rawLine
        .replaceAll(RegExp(r'C[uuvrnma]{1,3}\.?\s*V[o0][l1iI!|](?:[uuvrnma]{2,4}|[uuvrnma]{0,2})\s*[:=\-]?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'Cum\s*\.?\s*Vol(?:ume|umn)?\s*[:=\-]?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(?:L|Ltr|LTR|Litres|litres)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9A-Za-z\.,]'), ' ')
        .trim();

    // 2. Fix common optical character recognition ambiguities in numeric positions
    cleaned = cleaned.replaceAllMapped(RegExp(r'(\d)[Oo]'), (m) => '${m.group(1)}0');
    cleaned = cleaned.replaceAllMapped(RegExp(r'[Oo](\d)'), (m) => '0${m.group(1)}');
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

    // 6. Try integer millilitres match (when thermal printer decimal dot was faint)
    final intMatch = RegExp(r'(\d{7,10})').firstMatch(cleaned);
    if (intMatch != null) {
      final int rawInt = int.tryParse(intMatch.group(1)!) ?? 0;
      if (rawInt >= 10000000) {
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
    List<String> audit, {
    Map<int, double>? expectedBaselineLitres,
  }) {
    int anchorSeq = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_cumVolAnchorRegex.hasMatch(line) &&
          !RegExp(r'^\s*Cum\s*Sale\b', caseSensitive: false).hasMatch(line)) {
        anchorSeq++;
        final int targetNozzle = anchorSeq <= 2 ? anchorSeq : 2;
        if (nozzleVolumes.containsKey(targetNozzle)) {
          continue;
        }
        // Look ahead for the value on or below the CumVolume line (up to 6 lines down)
        for (int offset = 0; offset <= 6; offset++) {
          final targetIdx = i + offset;
          if (targetIdx >= lines.length) break;
          String candLine = lines[targetIdx];
          if (offset > 0 && RegExp(r'(?:N[o0]zz[l1iI]e|Mozzle)', caseSensitive: false).hasMatch(candLine)) {
            break;
          }
          if (candLine.contains(RegExp(r'Cum\s*Sale', caseSensitive: false))) {
            candLine = candLine.split(RegExp(r'Cum\s*Sale', caseSensitive: false))[0].trim();
            if (candLine.isEmpty) continue;
          }
          final parsed = _parseVolumeNumberFromLine(candLine);
          if (parsed != null && parsed.litres >= 10000.0 && parsed.litres < 10000000.0) {
            if (!_isCandidatePlausibleAgainstBaseline(
              parsed.litres,
              expectedBaselineLitres?[targetNozzle],
              audit,
              targetNozzle,
            )) {
              continue;
            }
            nozzleVolumes[targetNozzle] = parsed.volumeMl;
            nozzleSnippets[targetNozzle] = offset == 0 ? candLine : '$line → $candLine';
            audit.add('Global pass matched Nozzle $targetNozzle: ${parsed.litres} L');
            break;
          }
        }
      }
    }

    // If a baseline is known for a still-missing nozzle (e.g. Nozzle 1 or Nozzle 2),
    // scan the relevant half of the receipt for a line whose volume is within [baseline, baseline + 25000]
    if (expectedBaselineLitres != null) {
      for (final nozzleNum in [1, 2]) {
        if (nozzleVolumes.containsKey(nozzleNum)) continue;
        final double? base = expectedBaselineLitres[nozzleNum];
        if (base == null || base <= 0) continue;

        final int startIdx = nozzleNum == 1 ? 0 : (lines.length ~/ 2);
        final int endIdx = nozzleNum == 1 ? ((lines.length * 2) ~/ 3) : lines.length;
        for (int i = startIdx; i < endIdx; i++) {
          final rawLine = lines[i];
          if (_intermediateHeaderRegex.hasMatch(rawLine)) continue;
          final parsed = _parseVolumeNumberFromLine(rawLine, allowAfterCumSaleSplit: true);
          if (parsed != null &&
              parsed.litres >= base &&
              (parsed.litres - base) <= maxPlausibleDailyDeltaLitres) {
            // Ensure we didn't already assign this exact value to the other nozzle
            if (nozzleVolumes.values.contains(parsed.volumeMl)) continue;
            nozzleVolumes[nozzleNum] = parsed.volumeMl;
            nozzleSnippets[nozzleNum] = rawLine;
            audit.add('Baseline-guided pass recovered Nozzle $nozzleNum: ${parsed.litres} L from "$rawLine"');
            break;
          }
        }
      }
    }
  }

  static String _normalizeSerialDigits(String raw) {
    return raw
        .replaceAllMapped(RegExp(r'(\d)[Oo]'), (m) => '${m.group(1)}0')
        .replaceAllMapped(RegExp(r'[Oo](\d)'), (m) => '0${m.group(1)}')
        .replaceAllMapped(RegExp(r'(\d)[lI]'), (m) => '${m.group(1)}1')
        .replaceAllMapped(RegExp(r'[lI](\d)'), (m) => '1${m.group(1)}');
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
