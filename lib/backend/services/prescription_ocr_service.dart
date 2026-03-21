import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Result from OCR extraction
class OcrMedicineResult {
  final String medicineName;
  final String dosage;
  final String foodTiming;
  final String frequency;
  final String rawText;
  final String sourceType; // 'strip' | 'prescription' | 'pharmacy_bill' | 'unknown'

  const OcrMedicineResult({
    required this.medicineName,
    required this.dosage,
    required this.foodTiming,
    required this.frequency,
    required this.rawText,
    this.sourceType = 'unknown',
  });
}

/// Isolated OCR service for prescription scanning.
/// Uses line-level scoring to extract medicine names accurately.
class PrescriptionOCRService {
  static final _picker = ImagePicker();

  // ==================== PUBLIC ENTRY POINTS ====================

  static Future<List<OcrMedicineResult>> scanFromCamera() async {
    final file = await _pickImage(ImageSource.camera);
    if (file == null) return [];
    return _processImage(file);
  }

  static Future<List<OcrMedicineResult>> scanFromGallery() async {
    final file = await _pickImage(ImageSource.gallery);
    if (file == null) return [];
    return _processImage(file);
  }

  static Future<File?> _pickImage(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    return xfile != null ? File(xfile.path) : null;
  }

  // ==================== CORE PIPELINE ====================

  static Future<List<OcrMedicineResult>> _processImage(File file) async {
    final input = InputImage.fromFile(file);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognized = await recognizer.processImage(input);
    await recognizer.close();

    final rawText = recognized.text;
    if (rawText.trim().isEmpty) return [];

    final sourceType = _detectSourceType(rawText);
    final lines = _cleanLines(rawText);
    final candidates = _scoredCandidates(lines, sourceType);

    if (candidates.isEmpty) return [];

    // Build one OcrMedicineResult per detected medicine line
    return candidates.map((line) {
      return OcrMedicineResult(
        medicineName: _cleanMedicineName(line),
        dosage: _extractDosage(line),
        foodTiming: _extractFoodTiming(rawText),
        frequency: _extractFrequency(rawText),
        rawText: rawText,
        sourceType: sourceType,
      );
    }).toList();
  }

  // ==================== SOURCE DETECTION ====================

  static String _detectSourceType(String text) {
    final lower = text.toLowerCase();

    final pharmacyScore = _countMatches(lower, [
      '₹', 'mrp', 'gst', 'subtotal', 'total', 'invoice',
      'bill', 'tax', 'discount', 'amount',
    ]);

    final stripScore = _countMatches(lower, [
      'mfg', 'mfd', 'exp', 'batch', 'b.no', 'manufactured',
      'schedule h', 'store below',
    ]);

    final prescriptionScore = _countMatches(lower, [
      'rx', 'dr.', 'doctor', 'patient name', 'diagnosis',
      'prescribed', 'clinic', 'hospital', 'sig:',
    ]);

    if (pharmacyScore >= 2) return 'pharmacy_bill';
    if (stripScore >= 2) return 'strip';
    if (prescriptionScore >= 2) return 'prescription';
    return 'unknown';
  }

  static int _countMatches(String text, List<String> keywords) =>
      keywords.where((k) => text.contains(k)).length;

  // ==================== LINE CLEANING ====================

  // Lines to always skip regardless of score
  static final _noisePattern = RegExp(
    r'(mrp|mfg|mfd|exp\.|expiry|batch|b\.no|manufacture|store|keep|schedule|'
    r'address|phone|tel:|website|www\.|email|gst|hsn|lic|reg\.|'
    r'net content|strip of|pack of|'
    r'subtotal|total|invoice|bill|tax|discount|₹|rs\.|amount|'
    r'clinical|hospital name|clinic name|dr\.|rx\b|'
    r'^\d+[\.\)]\s|^s\.no|^sl\.no)',
    caseSensitive: false,
  );

  static List<String> _cleanLines(String text) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length > 2)
        .where((l) => !_noisePattern.hasMatch(l))
        .where((l) => !RegExp(r'^\d+$').hasMatch(l)) // pure numbers
        .where((l) => RegExp(r'[a-zA-Z]').hasMatch(l)) // must have letters
        .toList();
  }

  // ==================== SCORING ====================

  /// Score each line — only lines with score > 0 are medicine candidates.
  static List<String> _scoredCandidates(
      List<String> lines, String sourceType) {
    final scored = <MapEntry<String, int>>[];

    for (final line in lines) {
      int score = 0;
      final lower = line.toLowerCase();

      // Positive signals
      if (RegExp(r'\b\d+\s?(mg|ml|mcg|g)\b', caseSensitive: false)
          .hasMatch(line)) score += 2;
      if (RegExp(r'\b(tablet|tab|capsule|cap|syrup|syp|injection|inj|drops?)\b',
              caseSensitive: false)
          .hasMatch(line)) score += 2;
      if (RegExp(r'^[A-Z][a-z]').hasMatch(line)) score += 1; // Title case
      if (RegExp(r'^[A-Z]{2,}').hasMatch(line)) score += 1; // ALL CAPS med name

      // Negative signals — hard disqualifiers
      if (lower.contains('₹') || lower.contains('rs.')) score -= 5;
      if (lower.contains('gst') || lower.contains('tax')) score -= 5;
      if (lower.contains('total') || lower.contains('subtotal')) score -= 5;
      if (lower.contains('invoice') || lower.contains('bill no')) score -= 5;
      if (lower.contains('batch') || lower.contains('exp.')) score -= 3;
      if (RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}').hasMatch(line)) score -= 3; // dates
      if (line.length > 60) score -= 2; // very long lines are usually addresses

      // Pharmacy bill — extra penalty on all lines without mg/ml
      if (sourceType == 'pharmacy_bill' && score < 2) score -= 2;

      if (score > 0) scored.add(MapEntry(line, score));
    }

    // Sort by score desc, return top 5 at most
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(5).map((e) => e.key).toList();
  }

  // ==================== EXTRACTION HELPERS ====================

  static String _cleanMedicineName(String raw) {
    // Remove dosage, form keywords, trailing numbers
    return raw
        .replaceAll(
            RegExp(r'\b\d+\.?\d*\s?(mg|ml|mcg|g|iu|units?)\b',
                caseSensitive: false),
            '')
        .replaceAll(
            RegExp(
                r'\b(tablet|tab|capsule|cap|syrup|syp|injection|inj|drops?)\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[\s\-.,]+|[\s\-.,]+$'), '')
        .trim();
  }

  static String _extractDosage(String line) {
    // mg/ml pattern
    final mgMatch = RegExp(r'\b(\d+\.?\d*\s*(?:mg|ml|mcg|g|iu|units?))\b',
            caseSensitive: false)
        .firstMatch(line);
    if (mgMatch != null) return mgMatch.group(0)?.trim() ?? '';

    // 1-0-1 frequency as dosage
    final freqMatch = RegExp(r'\b([01]-[01]-[01])\b').firstMatch(line);
    if (freqMatch != null) return freqMatch.group(0)?.trim() ?? '';

    return '';
  }

  static String _extractFrequency(String text) {
    // 1-0-1 pattern
    final m = RegExp(r'\b([01]-[01]-[01])\b').firstMatch(text);
    if (m != null) return m.group(0) ?? '';

    final lower = text.toLowerCase();
    if (lower.contains('once daily') || lower.contains('od')) return 'Once daily';
    if (lower.contains('twice') || lower.contains('bd')) return 'Twice daily';
    if (lower.contains('thrice') || lower.contains('tds')) return 'Thrice daily';
    if (lower.contains('sos') || lower.contains('as needed')) return 'SOS';
    return '';
  }

  static String _extractFoodTiming(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('before food') ||
        lower.contains('before meal') ||
        lower.contains('empty stomach') ||
        lower.contains('a.c') ||
        lower.contains(' ac ')) {
      return 'Before Food';
    }
    if (lower.contains('with food') || lower.contains('with meal')) {
      return 'With Food';
    }
    // Default
    return 'After Food';
  }
}

