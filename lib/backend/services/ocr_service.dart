import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> scanFromCamera() async {
    final XFile? image =
    await _picker.pickImage(source: ImageSource.camera);

    if (image == null) return null;

    return _processImage(File(image.path));
  }

  static Future<String?> scanFromGallery() async {
    final XFile? image =
    await _picker.pickImage(source: ImageSource.gallery);

    if (image == null) return null;

    return _processImage(File(image.path));
  }

  static Future<String?> _processImage(File file) async {
    final inputImage = InputImage.fromFile(file);

    final textRecognizer =
    TextRecognizer(script: TextRecognitionScript.latin);

    final recognizedText =
    await textRecognizer.processImage(inputImage);

    await textRecognizer.close();

    final rawText = recognizedText.text;

    return _extractMedicineName(rawText);
  }

  static String? _extractMedicineName(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (final line in lines) {
      final lower = line.toLowerCase();

      if (lower.contains('tablet') ||
          lower.contains('tab') ||
          lower.contains('capsule') ||
          lower.contains('mg') ||
          lower.contains('syrup')) {

        if (lower.contains('clinic') ||
            lower.contains('hospital') ||
            lower.contains('dr') ||
            lower.contains('address') ||
            lower.contains('phone') ||
            lower.contains('patient')) {
          continue;
        }

        final cleaned = line
            .replaceAll(RegExp(r'\d+mg'), '')
            .replaceAll(RegExp(r'\d+'), '')
            .replaceAll(RegExp(r'\btab\b', caseSensitive: false), '')
            .replaceAll(RegExp(r'\btablet\b', caseSensitive: false), '')
            .replaceAll(RegExp(r'\bcapsule\b', caseSensitive: false), '')
            .trim();

        if (cleaned.length > 2) {
          return cleaned;
        }
      }
    }

    return lines.isNotEmpty ? lines.first : null;
  }
}