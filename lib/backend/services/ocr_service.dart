import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Result from OCR scan — structured extraction of prescription fields
class OcrResult {
  final String medicineName;
  final String dosage;
  final String foodTiming;
  final String rawText;
  final String sourceType; // 'strip', 'prescription', 'label'

  const OcrResult({
    required this.medicineName,
    required this.dosage,
    required this.foodTiming,
    required this.rawText,
    this.sourceType = 'unknown',
  });
}

class OcrService {
  static final ImagePicker _picker = ImagePicker();

  static Future<OcrResult?> scanFromCamera() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return null;
    return _processImage(File(image.path));
  }

  static Future<OcrResult?> scanFromGallery() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    return _processImage(File(image.path));
  }

  static Future<OcrResult?> _processImage(File file) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final rawText = recognizedText.text;
    if (rawText.trim().isEmpty) return null;

    final sourceType = _detectSourceType(rawText);
    final medicineName = _extractMedicineName(rawText, sourceType) ?? '';
    final dosage = _extractDosage(rawText);
    final foodTiming = _extractFoodTiming(rawText);

    if (medicineName.isEmpty && dosage.isEmpty) return null;

    return OcrResult(
      medicineName: medicineName,
      dosage: dosage,
      foodTiming: foodTiming,
      rawText: rawText,
      sourceType: sourceType,
    );
  }

  // ====================== SOURCE TYPE DETECTION ======================

  /// Detect if the scanned text is from a tablet strip, prescription paper, or label
  static String _detectSourceType(String text) {
    final lower = text.toLowerCase();

    // Tablet strip indicators
    final stripScore = _countMatches(lower, [
      'mrp', 'mfg', 'mfd', 'exp', 'batch', 'batch no', 'b.no',
      'manufactured', 'stored', 'keep away', 'schedule h',
    ]);

    // Prescription paper indicators
    final prescriptionScore = _countMatches(lower, [
      'rx', 'dr.', 'doctor', 'patient', 'diagnosis', 'prescribed',
      'clinic', 'hospital', 'name:', 'age:', 'date:', 'sig:', 'refill',
    ]);

    if (stripScore >= 2) return 'strip';
    if (prescriptionScore >= 2) return 'prescription';
    return 'label';
  }

  static int _countMatches(String text, List<String> keywords) {
    return keywords.where((k) => text.contains(k)).length;
  }

  // ====================== MEDICINE NAME EXTRACTION ======================

  static String? _extractMedicineName(String text, String sourceType) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Lines to always skip (noise)
    final skipPatterns = RegExp(
      r'(mrp|mfg|mfd|exp\.|expiry|batch|b\.no|manufacture|store|keep|schedule|'
      r'address|phone|tel:|website|www\.|email|gst|hsn|lic|reg\.|'
      r'net content|each tablet|each capsule|strip of|pack of|'
      r'clinical|hospital|dr\.|doctor|patient|diagnosis|rx\b|'
      r'^\d+[\.\)]\s)',
      caseSensitive: false,
    );

    List<String> candidates = [];

    if (sourceType == 'strip') {
      // On a tablet strip, the medicine name is usually:
      // - One of the first 3 lines
      // - Contains capital letters
      // - NOT a number-only line
      // - NOT a batch/mrp/expiry line
      for (final line in lines.take(6)) {
        if (skipPatterns.hasMatch(line)) continue;
        if (line.length < 3) continue;
        if (RegExp(r'^\d+$').hasMatch(line)) continue;

        // Prefer lines with medicine-like pattern (TitleCase or ALL CAPS with letters)
        if (RegExp(r'^[A-Z][a-zA-Z\s\-]+\s*\d*(mg|ml|mcg)?$').hasMatch(line) ||
            RegExp(r'^[A-Z]{2,}').hasMatch(line)) {
          candidates.add(_cleanMedicineName(line));
        }
      }
    } else if (sourceType == 'prescription') {
      // On a prescription, medicine names appear after 'Tab', 'Cap', 'Syp', 'Inj'
      for (final line in lines) {
        if (skipPatterns.hasMatch(line)) continue;

        final medPrefix = RegExp(
          r'(?:tab\.?|cap\.?|tablet|capsule|syp\.?|syrup|inj\.?|injection|drops?)\s+([A-Za-z][A-Za-z0-9\s\-+]+)',
          caseSensitive: false,
        );
        final match = medPrefix.firstMatch(line);
        if (match != null) {
          final name = _cleanMedicineName(match.group(1) ?? '');
          if (name.length > 2) candidates.add(name);
        }
      }

      // Also look for standalone capitalized medicine names
      if (candidates.isEmpty) {
        for (final line in lines) {
          if (skipPatterns.hasMatch(line)) continue;
          if (RegExp(r'^[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\s*\d*(mg|ml)?$')
              .hasMatch(line)) {
            candidates.add(_cleanMedicineName(line));
          }
        }
      }
    } else {
      // Generic label — same logic as prescription
      for (final line in lines) {
        if (skipPatterns.hasMatch(line)) continue;
        if (line.length < 3) continue;

        if (RegExp(r'^[A-Z][a-zA-Z]').hasMatch(line) &&
            !RegExp(r'^\d').hasMatch(line)) {
          final cleaned = _cleanMedicineName(line);
          if (cleaned.length > 2) candidates.add(cleaned);
        }
      }
    }

    // Return first valid candidate
    for (final c in candidates) {
      if (c.length > 2) return c;
    }

    // Final fallback — first non-noise line
    for (final line in lines) {
      if (!skipPatterns.hasMatch(line) &&
          line.length > 3 &&
          RegExp(r'[a-zA-Z]').hasMatch(line)) {
        return _cleanMedicineName(line);
      }
    }

    return null;
  }

  static String _cleanMedicineName(String raw) {
    return raw
        .replaceAll(RegExp(r'\b\d+\s?(mg|ml|mcg|g|iu|units?)\b',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(tablet|tab|capsule|cap|syrup|syp|injection|inj)\b',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[\s\-.]+|[\s\-.]+$'), '')
        .trim();
  }

  // ====================== DOSAGE EXTRACTION ======================

  static String _extractDosage(String text) {
    // Match patterns like "500mg", "10 mg", "250 ML", "1-0-1"
    final dosageRegex = RegExp(
      r'\b(\d+\.?\d*\s*(?:mg|ml|mcg|g|iu|units?))\b',
      caseSensitive: false,
    );
    final match = dosageRegex.firstMatch(text);
    if (match != null) return match.group(0)?.trim() ?? '';

    // Frequency pattern 1-0-1 / 1-1-1
    final freqRegex = RegExp(r'\b([01]-[01]-[01])\b');
    final freqMatch = freqRegex.firstMatch(text);
    if (freqMatch != null) return freqMatch.group(0)?.trim() ?? '';

    // Tablet count "1 tablet", "2 tabs"
    final tabletRegex = RegExp(
      r'\b(\d+\.?\d*\s*(?:tablet|tab|capsule|cap)s?)\b',
      caseSensitive: false,
    );
    final tabMatch = tabletRegex.firstMatch(text);
    if (tabMatch != null) return tabMatch.group(0)?.trim() ?? '';

    return '';
  }

  // ====================== FOOD TIMING EXTRACTION ======================

  static String _extractFoodTiming(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('before food') ||
        lower.contains('before meal') ||
        lower.contains('empty stomach') ||
        lower.contains('ac ') ||
        lower.contains('a.c')) {
      return 'Before Food';
    }
    if (lower.contains('after food') ||
        lower.contains('after meal') ||
        lower.contains('pc ') ||
        lower.contains('p.c') ||
        lower.contains('post meal') ||
        lower.contains('with food') ||
        lower.contains('with meal')) {
      return 'After Food';
    }

    return 'After Food'; // safe default
  }
}