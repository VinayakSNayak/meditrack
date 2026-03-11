import 'dart:io';
import 'dart:developer' as dev;
import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage service for prescription images.
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
      dev.log('[StorageService] uploadPrescriptionImage ▶  '
          'file=${file.path}  uid=$uid  prescriptionId=$prescriptionId',
          name: 'StorageService');

      // Preserve original extension so Firebase Storage sets correct content type
      final extension = file.path.split('.').last.toLowerCase();
      final validExtensions = ['jpg', 'jpeg', 'png', 'webp'];
      // HEIC/HEIF not supported by Image.network widget — treat as jpg
      final ext = validExtensions.contains(extension) ? extension : 'jpg';

      dev.log('[StorageService] detected extension="$extension" → using ext="$ext"',
          name: 'StorageService');

      final ref = _storage
          .ref()
          .child('prescriptions/$uid/$prescriptionId.$ext');

      dev.log('[StorageService] storage path: ${ref.fullPath}',
          name: 'StorageService');

      final metadata = SettableMetadata(
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
      );

      final task = await ref.putFile(file, metadata);
      dev.log('[StorageService] putFile complete  state=${task.state}',
          name: 'StorageService');

      final url = await ref.getDownloadURL();
      dev.log('[StorageService] uploadPrescriptionImage ✓  url=$url',
          name: 'StorageService');
      return url;
    } catch (e, stack) {
      dev.log('[StorageService] uploadPrescriptionImage ✗ FAILED: $e\n$stack',
          name: 'StorageService',
          error: e,
          stackTrace: stack);
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
