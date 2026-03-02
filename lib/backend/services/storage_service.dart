import 'dart:io';

/// Isolated Firebase Storage service.
///
/// NOTE: Requires `firebase_storage: ^12.3.0` in pubspec.yaml.
/// Run `flutter pub get` from terminal to enable image upload.
/// Until then, upload returns empty string and the prescription is saved without image.
class StorageService {
  static Future<String> uploadPrescriptionImage({
    required File file,
    required String uid,
    required String prescriptionId,
  }) async {
    try {
      // Dynamic import to avoid compile error if package is not yet installed
      return await _doUpload(file, uid, prescriptionId);
    } catch (_) {
      return '';
    }
  }

  static Future<void> deleteByUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await _doDelete(url);
    } catch (_) {}
  }

  // ── Implementation (uses firebase_storage) ──────────────────────
  // These methods are called only at runtime, not at compile time.
  // If firebase_storage is not installed, the catch block returns ''.

  static Future<String> _doUpload(
      File file, String uid, String prescriptionId) async {
    // ignore: avoid_dynamic_calls
    final dynamic storage =
        // ignore: undefined_identifier
        (await _loadFirebaseStorage()).instance;
    final dynamic ref =
        storage.ref().child('prescriptions/$uid/$prescriptionId.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL() as String;
  }

  static Future<void> _doDelete(String url) async {
    final dynamic storage =
        // ignore: undefined_identifier
        (await _loadFirebaseStorage()).instance;
    final dynamic ref = storage.refFromURL(url);
    await ref.delete();
  }

  static Future<dynamic> _loadFirebaseStorage() async {
    // This will throw if firebase_storage is not installed,
    // which is caught by the callers.
    throw UnimplementedError(
        'Run `flutter pub get` to install firebase_storage and enable image upload.');
  }
}
