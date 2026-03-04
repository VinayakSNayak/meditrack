import 'dart:io';
import 'dart:developer' as dev;
import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage service for prescription images.
/// Requires firebase_storage: ^12.3.0 (already in pubspec.yaml).
class StorageService {
  static final _storage = FirebaseStorage.instance;

  /// Upload a prescription image and return its download URL.
  /// Returns '' on any failure so the prescription is still saved without an image.
  static Future<String> uploadPrescriptionImage({
    required File file,
    required String uid,
    required String prescriptionId,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('prescriptions/$uid/$prescriptionId.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      dev.log('[StorageService] uploadPrescriptionImage failed: $e',
          name: 'StorageService');
      return '';
    }
  }

  /// Delete a stored image by its download URL. Silent on failure.
  static Future<void> deleteByUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      dev.log('[StorageService] deleteByUrl failed: $e',
          name: 'StorageService');
    }
  }
}
